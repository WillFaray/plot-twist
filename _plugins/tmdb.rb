# frozen_string_literal: true
# =============================================================
#  Plot Twist - TMDB enrichment plugin for Jekyll
# -------------------------------------------------------------
#  For every post that has `tmdb_id` in its front matter, this
#  plugin fetches the movie metadata from The Movie Database
#  (https://www.themoviedb.org) at build time and exposes it
#  on the post as `page.tmdb`. The post layout then renders
#  this data into the review page.
#
#  Behaviour:
#   - Caches the TMDB response on disk in `.jekyll-cache/tmdb/`
#     so repeated builds (and the GitHub-Actions build) are fast
#     and do not burn API quota.
#   - Downloads poster + backdrop images into
#     `assets/images/movies/<id>_poster.jpg` and
#     `assets/images/movies/<id>_backdrop.jpg` the first time,
#     so the deployed site is fully self-contained (no runtime
#     calls to TMDB).
#   - Skips the network entirely if no API key is set; the
#     layout degrades gracefully and the user can fill the
#     front matter by hand.
# =============================================================

require "json"
require "net/http"
require "uri"
require "fileutils"
require "digest"

module PlotTwist
  module TMDB
    IMAGE_BASE_DEFAULT = "https://image.tmdb.org/t/p/"

    def self.api_key(site)
      key = site.config.dig("tmdb", "api_key").to_s
      key = ENV["TMDB_API_KEY"] if key.empty?
      key
    end

    def self.config(site)
      c = site.config["tmdb"] || {}
      {
        "image_base"    => c["image_base"]    || IMAGE_BASE_DEFAULT,
        "poster_size"   => c["poster_size"]   || "w500",
        "backdrop_size" => c["backdrop_size"] || "w1280",
        "language"      => c["language"]      || "en-US",
      }
    end

    def self.cache_root(site)
      File.join(site.source, ".jekyll-cache", "tmdb")
    end

    def self.image_dir(site)
      File.join(site.source, "assets", "images", "movies")
    end

    def self.safe_id(id)
      id.to_s.gsub(/[^0-9a-zA-Z_-]/, "_")
    end

    # ---- HTTP with disk cache ------------------------------------------------
    def self.fetch_json(site, url)
      cache_dir = cache_root(site)
      FileUtils.mkdir_p(cache_dir)
      cache_key = Digest::SHA1.hexdigest(url)
      cache_file = File.join(cache_dir, "#{cache_key}.json")

      if File.exist?(cache_file)
        body = File.read(cache_file)
        return JSON.parse(body) if body && !body.empty?
      end

      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 8
      http.read_timeout = 12
      req = Net::HTTP::Get.new(uri.request_uri)
      req["Accept"] = "application/json"
      res = http.request(req)

      unless res.is_a?(Net::HTTPSuccess)
        Jekyll.logger.warn "TMDB", "HTTP #{res.code} for #{url}"
        return nil
      end

      File.write(cache_file, res.body)
      JSON.parse(res.body)
    rescue StandardError => e
      Jekyll.logger.warn "TMDB", "fetch failed for #{url}: #{e.class}: #{e.message}"
      nil
    end

    # ---- Image download ------------------------------------------------------
    def self.download(site, url, dest)
      return true if File.exist?(dest) && File.size(dest) > 0
      return false if url.nil? || url.empty?

      FileUtils.mkdir_p(File.dirname(dest))
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 8
      http.read_timeout = 20
      res = http.request(Net::HTTP::Get.new(uri.request_uri))
      return false unless res.is_a?(Net::HTTPSuccess)

      File.binwrite(dest, res.body)
      true
    rescue StandardError => e
      Jekyll.logger.warn "TMDB", "image download failed (#{url}): #{e.message}"
      false
    end

    # ---- Director lookup (from credits) --------------------------------------
    def self.director_of(movie_json)
      crew = movie_json.dig("credits", "crew")
      return nil unless crew.is_a?(Array)
      d = crew.find { |c| c["job"] == "Director" }
      d && d["name"]
    end

    # ---- Build the final page.tmdb hash --------------------------------------
    def self.enrich(post, site)
      id = post.data["tmdb_id"]
      return nil if id.nil? || id.to_s.empty?

      key = api_key(site)
      if key.nil? || key.empty?
        Jekyll.logger.warn "TMDB", "No API key set; skipping enrichment for #{post.data['title']}"
        return fallback_from_front_matter(post)
      end

      cfg = config(site)
      url = "https://api.themoviedb.org/3/movie/#{id}" \
            "?api_key=#{key}&language=#{cfg['language']}&append_to_response=credits"
      data = fetch_json(site, url)
      return fallback_from_front_matter(post) if data.nil?

      poster_path   = data["poster_path"]
      backdrop_path = data["backdrop_path"]
      poster_url    = poster_path   ? "#{cfg['image_base']}#{cfg['poster_size']}#{poster_path}"   : nil
      backdrop_url  = backdrop_path ? "#{cfg['image_base']}#{cfg['backdrop_size']}#{backdrop_path}" : nil

      idir = image_dir(site)
      sid  = safe_id(id)

      local_poster   = poster_url   ? download(site, poster_url,   File.join(idir, "#{sid}_poster.jpg"))   : false
      local_backdrop = backdrop_url ? download(site, backdrop_url, File.join(idir, "#{sid}_backdrop.jpg")) : false

      {
        "id"           => id,
        "year"         => (data["release_date"] || "")[0, 4],
        "runtime"      => data["runtime"].to_i > 0 ? "#{data['runtime']} min" : "",
        "overview"     => data["overview"].to_s,
        "tagline"      => data["tagline"].to_s,
        "vote_average" => data["vote_average"],
        "genres"       => Array(data["genres"]).map { |g| g["name"] },
        "director"     => director_of(data) || post.data["director"],
        "poster"       => local_poster   ? "/assets/images/movies/#{sid}_poster.jpg"   : (poster_url   || ""),
        "backdrop"     => local_backdrop ? "/assets/images/movies/#{sid}_backdrop.jpg" : (backdrop_url || ""),
      }
    end

    # If no API key / fetch failed, build a hash from front matter only.
    def self.fallback_from_front_matter(post)
      {
        "id"           => post.data["tmdb_id"],
        "year"         => post.data["year"] || (post.data["date"]&.year),
        "runtime"      => post.data["runtime"] || "",
        "overview"     => post.data["overview"] || post.data["synopsis"] || "",
        "tagline"      => post.data["tagline"] || "",
        "vote_average" => post.data["vote_average"] || "",
        "genres"       => Array(post.data["genres"]),
        "director"     => post.data["director"] || "",
        "poster"       => post.data["poster"] || "",
        "backdrop"     => post.data["backdrop"] || "",
      }
    end
  end
end

# ---- Hook: enrich every post with `tmdb_id` just before render ---------------
Jekyll::Hooks.register :posts, :pre_render do |post|
  next unless post.data["tmdb_id"]
  site = post.site
  post.data["tmdb"] = PlotTwist::TMDB.enrich(post, site)
end
