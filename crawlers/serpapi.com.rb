# frozen_string_literal: true

require "fileutils"
require "set"

# Renders every in-scope page in Chrome and saves a full-page screenshot,
# SerpApi's API landing pages by default. Run with:
#
#   bundle exec vessel start serpapi.com
class ScreenshotArchiver < ApplicationCrawler
  domain "serpapi.com"
  start_urls AppSettings::START_URL
  network_error_attempts 2

  # Trackers and widgets slow pages down and pop consent banners into the
  # screenshots. Ferrum-only feature: Chrome never loads these resources.
  blacklist [
    /googletagmanager/, /google-analytics/, /doubleclick/,
    /hotjar/, /facebook/, /intercom/, /twitter/
  ]

  @scheduled = Set[Urls.normalize(AppSettings::START_URL)]
  @lock = Mutex.new

  # Returns true when the url still fits the page budget and wasn't scheduled
  # before. Vessel already dedups urls (`once: true`), this adds the cap.
  def self.claim_slot?(url)
    @lock.synchronize do
      next false if @scheduled.include?(url) || @scheduled.size >= AppSettings::MAX_PAGES

      @scheduled << url
      true
    end
  end

  def before_start
    FileUtils.mkdir_p(AppSettings::SHOTS_DIR)
  end

  def parse
    current = Urls.normalize(url)

    # Scroll to the bottom so lazy-loaded images render, then back to the
    # top for the capture. `page` is the raw Ferrum::Page.
    page.execute("window.scrollTo(0, document.body.scrollHeight)")
    sleep 0.5
    page.execute("window.scrollTo(0, 0)")

    file = File.join(AppSettings::SHOTS_DIR, "#{Urls.slug(current)}.png")
    begin
      page.screenshot(path: file, full: true)
    rescue Ferrum::Error => e
      # Chrome refuses to capture extremely tall pages as one bitmap;
      # fall back to the viewport instead of losing the page.
      Vessel::Logger.instance.warn("full-page capture failed for #{current} (#{e.message}), using viewport")
      page.screenshot(path: file)
    end

    field :url, value: current
    field :title, value: page.evaluate("document.title") # stripped by the :title FieldType
    field :file, value: file
    yield fields

    outlinks = Set.new
    css("a[href]").each do |a|
      href = a[:href].to_s.strip
      next if href.empty? || href.start_with?("#", "mailto:", "tel:", "javascript:")

      target = Urls.normalize(absolute_url(href))
      outlinks << target if target && Urls.in_scope?(target) && target != current
    end

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

  # The engine is done, build the contact sheet.
  def after(_stats)
    Gallery.write_contact_sheet(start_url: AppSettings::START_URL, budget: AppSettings::MAX_PAGES)
  end
end
