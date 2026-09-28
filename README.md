# Plot Twist

Plot Twist is a movie review website created for an Instrumental English class.

The site presents personal reviews in a clean, responsive interface, combining written analysis with movie information such as posters, backdrops, genres, runtime, director, synopsis and ratings.

## About the Site

Plot Twist includes:

- A featured movie section on the homepage
- A responsive grid of movie reviews
- Individual review pages
- Ratings from 0 to 5 stars, including half-stars
- Movie metadata provided by The Movie Database
- Movie browsing by genre
- Light and dark color schemes
- Responsive layouts for desktop and mobile devices

Each review combines a personal text with visual and informational details about the movie, making the site easy to browse and focused on the films themselves.

## Built With

- Jekyll
- Ruby
- HTML
- SCSS
- Markdown
- The Movie Database API

## Run Locally

Install the Ruby dependencies and start the development server:

```sh
bundle install
bundle exec jekyll serve
```

The site will be available at `http://localhost:4000/plot-twist/`.

TMDB metadata is optional for a basic build. To enrich reviews with fresh
metadata and download artwork, copy `.env.example` to `.env` and set
`TMDB_API_KEY`. The `.env` file is ignored by Git and must never be committed.

To create a production build without starting the server:

```sh
JEKYLL_ENV=production bundle exec jekyll build
```

## Deploy

The workflow in `.github/workflows/jekyll.yml` deploys the `main` branch to
GitHub Pages. Configure the repository secret `TMDB_API_KEY` if the automated
build should fetch movie metadata and artwork. The site can still build without
that secret by using the information and assets already present in the repo.

## Project Structure

- `_posts/` contains the movie reviews
- `_layouts/` contains the page templates
- `_includes/` contains reusable components
- `_plugins/` handles movie metadata and generated pages
- `assets/css/` contains the site's styles
- `assets/images/movies/` contains movie artwork
- `_data/shop.yml` contains the demonstration shop catalogue

Generated folders such as `_site/`, `.jekyll-cache/` and `.sass-cache/` are
local build artifacts and are intentionally ignored by Git.

## Credits

Movie metadata and images are provided by [The Movie Database](https://www.themoviedb.org/).

## License

The code for this project is available for personal and educational use.