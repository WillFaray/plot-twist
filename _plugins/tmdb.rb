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
require "tempfile"

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
        "poster_size"        => c["poster_size"]        || "w500",
        "poster_size_small"  => c["poster_size_small"]  || "w185",
        "backdrop_size"      => c["backdrop_size"]      || "w1280",
        "backdrop_size_small" => c["backdrop_size_small"] || "w780",
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
    #  Every download is validated and written atomically:
    #   - the response body must be a real image (JPEG/PNG/WebP magic
    #     bytes) and fit a sane size range;
    #   - bytes go to a temp file in the destination directory and are
    #     only renamed into place after validation, so a failed or
    #     interrupted download can never leave a corrupt image behind.
    MIN_IMAGE_BYTES = 1024                # < 1 KB is never a real poster
    MAX_IMAGE_BYTES = 10 * 1024 * 1024    # 10 MB ceiling

    def self.valid_image_body?(body)
      return false if body.nil?
      return false if body.bytesize < MIN_IMAGE_BYTES
      return false if body.bytesize > MAX_IMAGE_BYTES
      sig = body.byteslice(0, 12)
      is_jpeg = sig.byteslice(0, 3) == "\xFF\xD8\xFF".b
      is_png  = sig.byteslice(0, 8) == "\x89PNG\r\n\x1A\n".b
      is_webp = sig.byteslice(0, 4) == "RIFF".b && sig.byteslice(8, 4) == "WEBP".b
      is_jpeg || is_png || is_webp
    end

    def self.download(site, url, dest)
      return true if File.exist?(dest) && File.size(dest) > 0
      return false if url.nil? || url.empty?

      FileUtils.mkdir_p(File.dirname(dest))
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 8
      http.read_timeout = 20
      req = Net::HTTP::Get.new(uri.request_uri)
      res = http.request(req)

      unless res.is_a?(Net::HTTPSuccess)
        Jekyll.logger.warn "TMDB", "HTTP #{res.code} for image #{url}"
        return false
      end

      body = res.body.to_s
      unless valid_image_body?(body)
        Jekyll.logger.warn "TMDB", "image failed validation (#{url})"
        return false
      end

      tmp = Tempfile.create(["tmdb-", File.extname(dest)], File.dirname(dest))
      moved = false
      begin
        tmp.binmode
        tmp.write(body)
        tmp.flush
        tmp.close
        FileUtils.mv(tmp.path, dest)
        moved = true
      ensure
        tmp.close! unless moved
      end
      true
    rescue StandardError => e
      Jekyll.logger.warn "TMDB", "image download failed (#{url}): #{e.message}"
      false
    end

    # Bundled placeholder used when a poster cannot be downloaded —
    # never keep external image.tmdb.org URLs in the built site.
    PLACEHOLDER_POSTER = "/assets/images/poster-placeholder.svg"

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
      poster_url      = poster_path   ? "#{cfg['image_base']}#{cfg['poster_size']}#{poster_path}"        : nil
      poster_sm_url   = poster_path   ? "#{cfg['image_base']}#{cfg['poster_size_small']}#{poster_path}"  : nil
      backdrop_url    = backdrop_path ? "#{cfg['image_base']}#{cfg['backdrop_size']}#{backdrop_path}"    : nil
      backdrop_sm_url = backdrop_path ? "#{cfg['image_base']}#{cfg['backdrop_size_small']}#{backdrop_path}" : nil

      idir = image_dir(site)
      sid  = safe_id(id)

      poster_path_local     = File.join(idir, "#{sid}_poster.jpg")
      poster_sm_path_local  = File.join(idir, "#{sid}_poster_sm.jpg")
      backdrop_path_local   = File.join(idir, "#{sid}_backdrop.jpg")
      backdrop_sm_path_local= File.join(idir, "#{sid}_backdrop_sm.jpg")

      ok_poster      = poster_url      ? download(site, poster_url,      poster_path_local)      : false
      ok_poster_sm   = poster_sm_url   ? download(site, poster_sm_url,   poster_sm_path_local)   : false
      ok_backdrop    = backdrop_url    ? download(site, backdrop_url,    backdrop_path_local)    : false
      ok_backdrop_sm = backdrop_sm_url ? download(site, backdrop_sm_url, backdrop_sm_path_local) : false

      # Only emit a *_sm.jpg URL when the file is actually on disk and
      # non-empty. The download can succeed (HTTP 200) while still
      # returning a 404 HTML body that fails our magic-bytes check, in
      # which case `ok_*_sm` will be false. The big images keep working
      # because they were committed to the repo earlier.
      has_poster_sm   = File.exist?(poster_sm_path_local)    && File.size(poster_sm_path_local)    > 0
      has_backdrop_sm = File.exist?(backdrop_sm_path_local) && File.size(backdrop_sm_path_local) > 0

      big_poster    = ok_poster    ? "/assets/images/movies/#{sid}_poster.jpg"    : nil
      small_poster  = has_poster_sm ? "/assets/images/movies/#{sid}_poster_sm.jpg" : nil
      big_backdrop  = ok_backdrop    ? "/assets/images/movies/#{sid}_backdrop.jpg"    : ""
      small_backdrop= has_backdrop_sm ? "/assets/images/movies/#{sid}_backdrop_sm.jpg" : ""

      {
        "id"             => id,
        "year"           => (data["release_date"] || "")[0, 4],
        "runtime"        => data["runtime"].to_i > 0 ? "#{data['runtime']} min" : "",
        "overview"       => data["overview"].to_s,
        "tagline"        => data["tagline"].to_s,
        "vote_average"   => data["vote_average"],
        "genres"         => Array(data["genres"]).map { |g| g["name"] },
        "director"       => director_of(data) || post.data["director"],
        # If the local download fails we fall back to the bundled
        # placeholder (posters) or to nothing (backdrops) — the built
        # site stays self-contained, with no external image URLs.
        "poster"         => big_poster || PLACEHOLDER_POSTER,
        "poster_small"   => small_poster || big_poster || PLACEHOLDER_POSTER,
        "backdrop"       => big_backdrop,
        "backdrop_small" => small_backdrop || big_backdrop,
      }
    end

    # If no API key / fetch failed, build a hash from front matter only.
    # Posters/backdrops downloaded by earlier builds still live on disk in
    # assets/images/movies/, so key-less rebuilds keep showing real art
    # instead of degrading to the placeholder.
    def self.fallback_from_front_matter(post)
      sid  = safe_id(post.data["tmdb_id"])
      dir  = image_dir(post.site)

      big_poster      = File.exist?(File.join(dir, "#{sid}_poster.jpg"))    ? "/assets/images/movies/#{sid}_poster.jpg"    : nil
      small_poster    = File.exist?(File.join(dir, "#{sid}_poster_sm.jpg")) ? "/assets/images/movies/#{sid}_poster_sm.jpg" : nil
      big_backdrop    = File.exist?(File.join(dir, "#{sid}_backdrop.jpg"))    ? "/assets/images/movies/#{sid}_backdrop.jpg"    : nil
      small_backdrop  = File.exist?(File.join(dir, "#{sid}_backdrop_sm.jpg")) ? "/assets/images/movies/#{sid}_backdrop_sm.jpg" : nil

      author_poster   = post.data["poster"].to_s
      author_backdrop = post.data["backdrop"].to_s

      {
        "id"             => post.data["tmdb_id"],
        "year"           => post.data["year"] || (post.data["date"]&.year),
        "runtime"        => post.data["runtime"] || "",
        "overview"       => post.data["overview"] || post.data["synopsis"] || "",
        "tagline"        => post.data["tagline"] || "",
        "vote_average"   => post.data["vote_average"] || "",
        "genres"         => Array(post.data["genres"]),
        "director"       => post.data["director"] || "",
        "poster"         => author_poster.empty?    ? (big_poster    || PLACEHOLDER_POSTER) : author_poster,
        "poster_small"   => author_poster.empty?    ? (small_poster  || "") : author_poster,
        "backdrop"       => author_backdrop.empty?  ? (big_backdrop  || "") : author_backdrop,
        "backdrop_small" => author_backdrop.empty?  ? (small_backdrop || big_backdrop || "") : author_backdrop,
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
