# frozen_string_literal: true

require "uri"

# Runtime settings, tweakable via environment variables:
#
#   SCOPE_PATTERN='-api$' MAX_PAGES=10 bundle exec vessel start serpapi.com
module AppSettings
  START_URL = ENV.fetch("START_URL", "https://serpapi.com/")
  MAX_PAGES = Integer(ENV.fetch("MAX_PAGES", 50))
  SHOTS_DIR = ENV.fetch("SHOTS_DIR", "shots")
  SCOPE = URI(START_URL)

  # Regex matched against URL paths; overrides the default path-prefix
  # scoping. Defaults to SerpApi's API landing pages (/google-maps-api, ...).
  pattern = ENV.fetch("SCOPE_PATTERN", "-api$")
  SCOPE_PATTERN = pattern.empty? ? nil : Regexp.new(pattern)
end
