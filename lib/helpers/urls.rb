# frozen_string_literal: true

require "uri"

module Urls
  ASSET_EXTENSIONS = /\.(png|jpe?g|gif|svg|webp|ico|css|js|json|pdf|zip|gz|xml|rss|atom|mp3|mp4|woff2?|ttf)\z/i

  module_function

  # Strip fragments and query strings, drop trailing slashes so that
  # /docs and /docs/ count as one page.
  def normalize(url)
    uri = URI(url.to_s)
    return nil unless %w[http https].include?(uri.scheme)

    uri.fragment = nil
    uri.query = nil
    uri.path = "/" if uri.path.empty?
    uri.path = uri.path.chomp("/") unless uri.path == "/"
    uri.to_s
  rescue URI::Error
    nil
  end

  def scope_prefix
    @scope_prefix ||= AppSettings::SCOPE.path.chomp("/")
  end

  # Same host, and either under the start URL's path (default) or matching
  # SCOPE_PATTERN when given, for pages that share no path prefix, like
  # serpapi.com's API landing pages (/google-maps-api, /bing-search-api, ...).
  def in_scope?(url)
    uri = URI(url)
    return false unless uri.host == AppSettings::SCOPE.host
    return false if uri.path.match?(ASSET_EXTENSIONS)

    return uri.path.match?(AppSettings::SCOPE_PATTERN) if AppSettings::SCOPE_PATTERN

    prefix = scope_prefix
    prefix.empty? || uri.path == prefix || uri.path.start_with?("#{prefix}/")
  rescue URI::Error
    false
  end

  def slug(url)
    path = URI(url).path.delete_prefix("/")
    return "index" if path.empty?

    path.gsub(/[^a-zA-Z0-9]+/, "-").squeeze("-").delete_suffix("-")
  end
end
