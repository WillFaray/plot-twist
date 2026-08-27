---
layout: page
title: About
permalink: /about/
---

# About Plot Twist

**Plot Twist** is a small, hand-written movie-review website built for an
Instrumental English class. The idea is simple: pick a film, watch it in
English, write a short review in English, and publish it as a Markdown file.

## How it works

1. Each review lives in a `.md` file under `_posts/`. The front matter
   carries the TMDB id and a star rating from `0` to `5`.
2. At build time, a small Jekyll plugin talks to the
   [TMDB API](https://www.themoviedb.org/), fetches the poster, the
   backdrop, the synopsis, the director and the genres, and downloads
   the cover art so the deployed site is fully self-contained.
3. The layout renders a review page with the cover art centered, a
   metadata table, golden stars for the rating and the author's text
   underneath.

## How to add a new review

Create a file in `_posts/` named `YYYY-MM-DD-some-title.md`:

```yaml
---
layout: movie
title: "Inception"
tmdb_id: 27205
rating: 4.5
date: 2026-08-27
---

Write your thoughts here. You can use **bold**, *italics*, > quotes,
links, images, and lists.
```

Run `bundle exec jekyll serve` and your review is live at
`/movies/YYYY/MM/DD/some-title/`.

## Credits

- Built with [Jekyll](https://jekyllrb.com/).
- Movie metadata from [The Movie Database](https://www.themoviedb.org/).
  This product uses the TMDB API but is not endorsed or certified by TMDB.
- Fonts: [Inter](https://rsms.me/inter/).
