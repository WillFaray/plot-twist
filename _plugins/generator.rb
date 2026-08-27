# frozen_string_literal: true
# =============================================================
#  Plot Twist - Page generators
# -------------------------------------------------------------
#  Auto-creates two extra pages even if the user did not write
#  them by hand:
#
#   /movies/  -> paginated list of all movie reviews
#   /genres/  -> index grouped by genre (links to filtered lists)
#
#  If the user already has movies.md / genres.md with `layout:
#  page`, those win.
# =============================================================

module PlotTwist
  class MoviesPageGenerator < Jekyll::Generator
    safe true
    priority :low

    def generate(site)
      return if site.pages.any? { |p| p.url =~ %r{/movies/?$} || p.url =~ %r{/movies/index\.html$} }

      site.pages << MovieIndexPage.new(site, site.source)
      Jekyll.logger.info "PlotTwist", "Generated /movies/ index page"
    end
  end

  class GenresPageGenerator < Jekyll::Generator
    safe true
    priority :low

    def generate(site)
      return if site.pages.any? { |p| p.url =~ %r{/genres/?$} || p.url =~ %r{/genres/index\.html$} }

      site.pages << GenreIndexPage.new(site, site.source)
      Jekyll.logger.info "PlotTwist", "Generated /genres/ index page"
    end
  end

  # ---- /movies/ ------------------------------------------------------------
  class MovieIndexPage < Jekyll::Page
    def initialize(site, base)
      @site = site
      @base = base
      @dir  = "/movies"
      @name = "index.html"
      @ext  = File.extname(@name)
      @data = {
        "layout"  => "movies",
        "title"   => "All Reviews",
        "permalink" => "/movies/",
      }
    end
  end

  # ---- /genres/ ------------------------------------------------------------
  class GenreIndexPage < Jekyll::Page
    def initialize(site, base)
      @site = site
      @base = base
      @dir  = "/genres"
      @name = "index.html"
      @ext  = File.extname(@name)
      @data = {
        "layout"  => "genres",
        "title"   => "Browse by Genre",
        "permalink" => "/genres/",
      }
    end
  end
end

# =============================================================
#  Genre index data file generator
# -------------------------------------------------------------
#  After every post has been enriched with TMDB data, walk the
#  collection and build a slug => { name, count, posts: [...] }
#  hash that the /genres/ layout consumes.
# =============================================================
# ---- Liquid filter: build a genre bucket on demand ---------------------------
# Walks all posts and groups them by their TMDB genre. This is the single
# source of truth for the genre dropdowns in the header and the /genres/
# page, and it runs lazily inside the template, so it always sees the
# enriched `tmdb` data populated by `_plugins/tmdb.rb`.
module Jekyll
  module GenreFilter
    # Accept an optional input so it can be used as either
    #   {{ '' | genre_bucket }}        # output piped in (ignored)
    #   {% assign g = genre_bucket %}  # bare call (Jekyll 4 supports this)
    def genre_bucket(input = nil)
      _ = input
      bucket = {}
      @context.registers[:site].posts.docs.each do |post|
        next unless post.data["layout"] == "movie"
        genres = post.data.dig("tmdb", "genres") || []
        genres.each do |g|
          slug = g.to_s.downcase.strip.gsub(/[^a-z0-9]+/, "-").gsub(/(^-|-$)/, "")
          next if slug.empty?
          bucket[slug] ||= { "name" => g, "count" => 0, "posts" => [] }
          bucket[slug]["count"] += 1
          bucket[slug]["posts"] << post
        end
      end
      bucket
    end
  end
end
Liquid::Template.register_filter(Jekyll::GenreFilter)
