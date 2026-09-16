# Vessel website screenshot archiver

A Vessel 0.3 example showing the Ferrum driver running real Chrome. It crawls a site with [Vessel](https://github.com/rubycdp/vessel), renders every page in headless Chrome, and saves a full-page screenshot per page plus an `index.html` contact sheet. Useful as a visual archive before a redesign, for eyeballing a whole site at once, or for visual regression checks.

Check out the accompanying [Vessel 0.3: Ruby finally gets its Scrapy](https://serpapi.com/blog/vessel-ruby-crawling-framework/) post.

## Requirements

Chrome or Chromium installed (the Ferrum driver finds it automatically on
macOS; otherwise it must be in `PATH`).

## Usage

Here's the basic usage:

```ruby
bundle install

# Screenshot SerpApi's API landing pages (they live at the root of the
# domain with no shared path prefix, so scope by regex instead of by path):
SCOPE_PATTERN='-api$' MAX_PAGES=10 bundle exec ruby screenshot_archiver.rb https://serpapi.com/

# Or scope by path prefix (only URLs under /docs/ are followed):
bundle exec ruby screenshot_archiver.rb https://example.com/docs/

open shots/index.html
```

Options via environment variables:

```ruby
SCOPE_PATTERN='-api$' MAX_PAGES=10 THREADS=2 SHOTS_DIR=shots bundle exec ruby screenshot_archiver.rb https://serpapi.com/
```

- `SCOPE_PATTERN` — regex matched against URL paths; overrides the default
  path-prefix scoping
- `MAX_PAGES` — page budget for the crawl (default 50)
- `THREADS` — thread pool size, one Chrome page each (default 2)
- `SHOTS_DIR` — output directory (default `shots`)

## Output

Script will save output to `shots/` by default:

- `shots/<page-slug>.png` — full-page screenshot per crawled page
- `shots/index.html` — contact sheet with all screenshots, titles, and links

## Vessel vs Mechanize

Here's the advantage of Vessel 0.3 compared to Mechanize:

- `page` inside a handler is the raw `Ferrum::Page`: the script scrolls to the
  bottom so lazy-loaded images render, scrolls back, and calls
  `page.screenshot(full: true)`.
- `blacklist` patterns keep Chrome from loading trackers and widgets, which
  speeds up the crawl and keeps consent banners out of the screenshots.
- `driver :ferrum, headless: true, window_size: [1280, 800], timeout: 30`
  passes options straight to `Ferrum::Browser.new`.

## Notes

- Screenshots are heavy; the default budget is 50 pages and 2 threads. Full
  runs against big sites will take a while and use real bandwidth.
- Chrome cannot capture extremely tall pages as a single full-page bitmap (it
  hits a texture size limit) and very long captures can exceed the timeout.
  The script falls back to a viewport screenshot for those pages and logs a
  warning.
- URL scoping keeps the crawl on the start URL's host, and either under its
  path prefix (default) or matching `SCOPE_PATTERN`. URLs are normalized
  (fragments and query strings stripped, trailing slashes dropped) and asset
  URLs (images, CSS, feeds, ...) are skipped.
