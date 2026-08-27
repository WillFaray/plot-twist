# frozen_string_literal: true
# =============================================================
#  Plot Twist - .env loader
# -------------------------------------------------------------
#  Loads variables from a .env file in the site root before any
#  other plugin runs, so TMDB_API_KEY (and friends) are visible
#  to the TMDB enrichment plugin.
#
#  - Skips comments and blank lines
#  - Strips optional "export " prefix
#  - Does NOT overwrite an env var that is already set in the
#    real environment (so CI / shell exports win)
#  - Is a no-op if no .env file is present
# =============================================================

require "dotenv"

Jekyll::Hooks.register :site, :after_init do |site|
  env_file = File.join(site.source, ".env")
  next unless File.exist?(env_file)

  Dotenv.load(env_file)
  Jekyll.logger.info "PlotTwist", "Loaded .env from #{env_file}"
rescue StandardError => e
  Jekyll.logger.warn "PlotTwist", "Could not load .env: #{e.class}: #{e.message}"
end
