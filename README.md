# Plot Twist — Movie Reviews

A small, modern website of movie reviews built with **Jekyll** and
deployed to **GitHub Pages** for an Instrumental English class.

## Features

- 📝 **Reviews as Markdown.** Each film is a `.md` file inside `_posts/`.
  Front matter drives everything else.
- 🎬 **Automatic TMDB enrichment.** Just add `tmdb_id: 603` and the
  build fetches the poster, backdrop, director, runtime, genres and
  synopsis from The Movie Database. Images are downloaded into
  `assets/images/movies/` so the deployed site is fully self-contained
  and does not call TMDB at runtime.
- ⭐ **Star ratings from 0 to 5.** The `rating:` field in front matter
  renders a 5-star component with support for half-stars.
- 🎨 **Modern, clean design.** Dark by default, light scheme auto, fully
  responsive, with a sticky header, hero, movie grid, paginated lists
  and a per-genre index.
- 🚀 **Zero-config deploys.** Push to `main` and GitHub Pages builds it.

## Quick start

```bash
bundle install
bundle exec jekyll serve
```

Then open <http://localhost:4000>.

### Configure TMDB (one-time)

1. Create a free account at <https://www.themoviedb.org/>.
2. Request an API key (v3) at <https://www.themoviedb.org/settings/api>.
3. Either:
   - Set the env var `export TMDB_API_KEY=xxxxxxxxxxxxxxxx`, **or**
   - Paste it into `_config.yml` under `tmdb.api_key`.

Without a key the site still builds; the layout simply falls back to
whatever is in the post front matter (and to a placeholder poster).

## How to add a new review

The fastest way is to use the helper script:

```bash
./scripts/new-review.sh "Inception" 27205 4.5
```

That creates a properly-named file under `_posts/` with the correct
front matter. Edit the file and write your review below the front
matter.

You can also create the file by hand at `_posts/YYYY-MM-DD-my-movie.md`:

```markdown
---
layout: movie
title: "Inception"
date: 2026-08-27 10:00:00 -0300
tmdb_id: 27205
rating: 4.5
excerpt: "A thief who steals corporate secrets through dream-sharing technology."
---

Write your review in plain Markdown. Headings, bold, italics, lists,
links and images all work.
```

You can find a movie's `tmdb_id` by visiting its page on
[themoviedb.org](https://www.themoviedb.org/) — it is the number in the
URL, e.g. `themoviedb.org/movie/27205-inception` → `tmdb_id: 27205`.

The build will then:

1. Hit the TMDB API (once, cached on disk) and grab all metadata.
2. Download the poster and backdrop into `assets/images/movies/`.
3. Render a review page with cover, synopsis, metadata table, stars
   and your text.

## File layout

```
.
├── _config.yml              # Site configuration
├── _plugins/
│   ├── tmdb.rb              # Fetches metadata from TMDB
│   └── generator.rb         # Generates /movies/ and /genres/ pages
├── _layouts/
│   ├── default.html         # Base layout (header, footer)
│   ├── home.html            # Landing page
│   ├── page.html            # Generic prose page
│   ├── movie.html           # Single review
│   ├── movies.html          # Full list
│   └── genres.html          # Grouped by genre
├── _includes/
│   ├── header.html
│   ├── footer.html
│   ├── movie-card.html
│   └── stars.html
├── _posts/                  # One .md per movie
├── assets/
│   ├── css/main.scss        # Stylesheet
│   └── images/movies/       # Cached posters / backdrops
├── index.md
├── about.md
├── 404.html
└── Gemfile
```

## Deploying to GitHub Pages

1. Push this repository to GitHub.
2. In **Settings → Pages**, set the source to **GitHub Actions** and
   commit a workflow at `.github/workflows/jekyll.yml` (template below)
   that runs `bundle exec jekyll build` and uploads `_site/`.
3. Each push to `main` rebuilds the site.

Minimal workflow:

```yaml
name: Deploy Jekyll site to GitHub Pages
on:
  push: { branches: [main] }
permissions: { contents: read, pages: write, id-token: write }
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/configure-pages@v4
      - uses: actions/cache@v4
        with: { path: vendor, key: gems }
      - uses: helaili/jekyll-action@main
        with: { token: ${{ secrets.GITHUB_TOKEN }} }
```

You can also enable Pages from the `gh-pages` branch the classic way and
use the built-in `github-pages` gem; the layout works either way.

## License

The code is yours. The movie metadata is provided by TMDB; please
attribute them per their [terms of use](https://www.themoviedb.org/documentation/api/terms-of-use).
