#!/usr/bin/env bash
# =================================================================
#  new-review.sh
#  Creates a new movie-review markdown file with a working front
#  matter template.
#
#  Usage:
#     ./scripts/new-review.sh "Inception" 27205 4.5
#
#  Args:
#     $1 = movie title (quote it; Unicode is transliterated in the slug)
#     $2 = TMDB id (positive integer)
#     $3 = rating (0..5, in 0.5 steps; default 0)
# =================================================================
set -euo pipefail

usage() {
  echo "usage: $0 \"Title\" tmdb_id [rating]" >&2
  exit 1
}

[[ $# -ge 2 ]] || usage
TITLE="$1"
TMDB_ID="$2"
RATING="${3:-0}"

# --- validation -----------------------------------------------------------
[[ "$TMDB_ID" =~ ^[0-9]+$ ]] || {
  echo "error: tmdb_id must be a positive integer (got '$TMDB_ID')" >&2
  exit 1
}

[[ "$RATING" =~ ^[0-5]([.][05])?$ ]] || {
  echo "error: rating must be between 0 and 5, in 0.5 steps (got '$RATING')" >&2
  exit 1
}

# non-empty, no control characters (newlines would break the front matter)
[[ -n "$TITLE" && ! "$TITLE" =~ [[:cntrl:]] ]] || {
  echo "error: title must be non-empty and free of control characters" >&2
  exit 1
}

# --- YAML-safe title ------------------------------------------------------
# Write as a single-quoted YAML scalar; single quotes are doubled.
TITLE_YAML="${TITLE//\'/\'\'}"

# --- slug -----------------------------------------------------------------
# Transliterate Unicode to ASCII when iconv is available ("Amélie" ->
# "amelie"), then strip everything outside [a-z0-9-]. If nothing usable
# survives, abort instead of writing an unreadable filename.
if command -v iconv >/dev/null 2>&1; then
  SLUG="$(printf '%s' "$TITLE" \
    | iconv -f UTF-8 -t ASCII//TRANSLIT//IGNORE 2>/dev/null \
    || printf '%s' "$TITLE")"
else
  SLUG="$TITLE"
fi
SLUG="$(printf '%s' "$SLUG" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"
[[ -n "$SLUG" ]] || {
  echo "error: could not build a filename slug from the title '$TITLE'" >&2
  exit 1
}

DATE="$(date +%Y-%m-%d)"
FILE="_posts/${DATE}-${SLUG}.md"
if [[ -e "$FILE" ]]; then
  echo "error: $FILE already exists" >&2
  exit 1
fi

mkdir -p _posts
cat > "$FILE" << EOF
---
layout: movie
title: '$TITLE_YAML'
date: $(date +'%Y-%m-%d %H:%M:%S %z')
tmdb_id: $TMDB_ID
rating: $RATING
excerpt: ''
---

Write your review in plain Markdown.
EOF

echo "Created $FILE"
echo "Next: edit the review body, then rebuild (bundle exec jekyll serve)."
