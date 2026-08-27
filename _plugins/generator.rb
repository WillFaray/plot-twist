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
Jekyll::Hooks.register :site, :post_read do |site|
  bucket = {}
  site.posts.each do |post|
    next unless post.data["layout"] == "movie"
    genres = post.data.dig("tmdb", "genres") || []
    genres.each do |g|
      slug = g.to_s.downcase.strip
      next if slug.empty?
      bucket[slug] ||= { "name" => g, "count" => 0, "posts" => [] }
      bucket[slug]["count"] += 1
      # Store the post reference; Jekyll can resolve these in templates.
      bucket[slug]["posts"] << post
    end
  end
  site.data["genres"] = bucket
end
