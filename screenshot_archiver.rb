#!/usr/bin/env ruby
# frozen_string_literal: true

# Crawls a site (scoped to the start URL's host, and its path prefix or a
# SCOPE_PATTERN regex) with a real Chrome via Vessel's Ferrum driver and saves
# a full-page screenshot of every page, plus an index.html contact sheet to
# browse them.
#
# Usage:
#   # SerpApi's API landing pages share no path prefix, scope by regex:
#   SCOPE_PATTERN='-api$' MAX_PAGES=10 bundle exec ruby screenshot_archiver.rb https://serpapi.com/
#
#   # Or scope by path prefix (only URLs under /docs/ are followed):
#   bundle exec ruby screenshot_archiver.rb https://example.com/docs/
#
# Requires Chrome or Chromium (the Ferrum driver finds it automatically).
#
# Outputs:
#   - shots/<page-slug>.png  full-page screenshot per crawled page
#   - shots/index.html       contact sheet of all screenshots

require "cgi"
require "fileutils"
require "logger"
require "set"
require "uri"
require "vessel"

START_URL = ARGV[0] || abort("Usage: bundle exec ruby screenshot_archiver.rb <start-url>")
MAX_PAGES = Integer(ENV.fetch("MAX_PAGES", 50))
SCOPE = URI(START_URL)
SCOPE_PATTERN = ENV["SCOPE_PATTERN"] && Regexp.new(ENV["SCOPE_PATTERN"])
SHOTS_DIR = ENV.fetch("SHOTS_DIR", "shots")

# Vessel logs at debug level to $stdout by default; keep stdout for the report.
Vessel::Logger.instance = Logger.new($stderr, level: Logger::WARN)

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
    @scope_prefix ||= SCOPE.path.chomp("/")
  end

  # Same host, and either under the start URL's path (default) or matching
  # SCOPE_PATTERN when given, for pages that share no path prefix, like
  # serpapi.com's API landing pages (/google-maps-api, /bing-search-api, ...).
  def in_scope?(url)
    uri = URI(url)
    return false unless uri.host == SCOPE.host
    return false if uri.path.match?(ASSET_EXTENSIONS)

    return uri.path.match?(SCOPE_PATTERN) if SCOPE_PATTERN

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

class ScreenshotArchiver < Vessel::Cargo
  domain SCOPE.host
  start_urls START_URL
  driver :ferrum, headless: true, window_size: [1280, 800], timeout: 30
  threads max: Integer(ENV.fetch("THREADS", 2))
  network_error_attempts 2

  # Trackers and widgets slow pages down and pop consent banners into the
  # screenshots. Ferrum-only feature: Chrome never loads these resources.
  blacklist [
    /googletagmanager/, /google-analytics/, /doubleclick/,
    /hotjar/, /facebook/, /intercom/, /twitter/
  ]

  @scheduled = Set[Urls.normalize(START_URL)]
  @lock = Mutex.new

  # Returns true when the url still fits the page budget and wasn't scheduled
  # before. Vessel already dedups urls (`once: true`), this adds the cap.
  def self.claim_slot?(url)
    @lock.synchronize do
      next false if @scheduled.include?(url) || @scheduled.size >= MAX_PAGES

      @scheduled << url
      true
    end
  end

  def parse
    current = Urls.normalize(url)

    # Scroll to the bottom so lazy-loaded images render, then back to the
    # top for the capture. `page` is the raw Ferrum::Page.
    page.execute("window.scrollTo(0, document.body.scrollHeight)")
    sleep 0.5
    page.execute("window.scrollTo(0, 0)")

    file = File.join(SHOTS_DIR, "#{Urls.slug(current)}.png")
    begin
      page.screenshot(path: file, full: true)
    rescue Ferrum::Error => e
      # Chrome refuses to capture extremely tall pages as one bitmap;
      # fall back to the viewport instead of losing the page.
      Vessel::Logger.instance.warn("full-page capture failed for #{current} (#{e.message}), using viewport")
      page.screenshot(path: file)
    end

    outlinks = Set.new
    css("a[href]").each do |a|
      href = a[:href].to_s.strip
      next if href.empty? || href.start_with?("#", "mailto:", "tel:", "javascript:")

      target = Urls.normalize(absolute_url(href))
      outlinks << target if target && Urls.in_scope?(target) && target != current
    end

    yield({ url: current, title: page.evaluate("document.title").to_s.strip, file: file })

    outlinks.each do |link|
      yield request(url: link, handler: :parse) if self.class.claim_slot?(link)
    end
  end

  # The default on_error re-raises; log and move on instead.
  def on_error(request, error)
    Vessel::Logger.instance.warn(
      "skipping #{request&.url}: #{error.class}: #{error.message.lines.first.to_s.strip}"
    )
  end
end

# --- Crawl ------------------------------------------------------------------

FileUtils.mkdir_p(SHOTS_DIR)

pages = []
lock = Mutex.new

ScreenshotArchiver.run { |item| lock.synchronize { pages << item } }

abort "No pages captured. Is #{START_URL} reachable?" if pages.empty?

pages.sort_by! { |p| p[:url] }

# --- Contact sheet ------------------------------------------------------------

cards = pages.map do |p|
  name = File.basename(p[:file])
  title = CGI.escapeHTML(p[:title])
  path = CGI.escapeHTML(URI(p[:url]).path)

  <<~CARD
    <figure>
      <a href="#{name}"><img src="#{name}" loading="lazy" alt="#{title}"></a>
      <figcaption><strong>#{title}</strong><br><a href="#{CGI.escapeHTML(p[:url])}">#{path}</a></figcaption>
    </figure>
  CARD
end.join

File.write(File.join(SHOTS_DIR, "index.html"), <<~HTML)
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Screenshots of #{CGI.escapeHTML(START_URL)}</title>
    <style>
      body { font-family: system-ui, sans-serif; margin: 2rem; }
      main { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 1.5rem; }
      figure { margin: 0; }
      img { width: 100%; height: 300px; object-fit: cover; object-position: top; border: 1px solid #ccc; border-radius: 4px; }
      figcaption { font-size: 0.85rem; margin-top: 0.4rem; }
      a { color: inherit; }
    </style>
  </head>
  <body>
    <h1>#{pages.size} pages under #{CGI.escapeHTML(START_URL)}</h1>
    <main>#{cards}</main>
  </body>
  </html>
HTML

puts "Captured #{pages.size} pages (budget: #{MAX_PAGES}) into #{SHOTS_DIR}/"
puts "Contact sheet: open #{File.join(SHOTS_DIR, "index.html")}"
