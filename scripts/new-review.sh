#!/usr/bin/env bash
# =================================================================
#  new-review.sh
#  Creates a new movie-review markdown file with a working front
#  matter template. Usage:
#     ./scripts/new-review.sh "Inception" 27205 4.5
#  Args:
#     $1 = movie title
#     $2 = TMDB id (integer)
#     $3 = rating (0..5)
# =================================================================
set -euo pipefail
TITLE="${1:?usage: $0 \"Title\" tmdb_id rating}"
TMDB_ID="${2:?missing TMDB id}"
RATING="${3:-0}"
DATE="$(date +%Y-%m-%d)"
SLUG="$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"
FILE="_posts/${DATE}-${SLUG}.md"
if [[ -f "$FILE" ]]; then
  echo "error: $FILE already exists" >&2; exit 1
fi
cat > "$FILE" << EOF
---
layout: movie
title: "$TITLE"
date: $(date +'%Y-%m-%d %H:%M:%S %z')
tmdb_id: $TMDB_ID
rating: $RATING
excerpt: ""
---

Write your review in plain Markdown.
EOF
echo "Created $FILE"
