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

# Screenshot SerpApi's API landing pages (the default scope; they live at
# the root of the domain with no shared path prefix, so the crawler scopes
# by regex instead of by path):
MAX_PAGES=10 bundle exec vessel start serpapi.com

# Or scope by path prefix (set SCOPE_PATTERN empty; only URLs under /docs/
# are followed):
SCOPE_PATTERN='' START_URL=https://example.com/docs/ bundle exec vessel start serpapi.com

open shots/index.html
```

Options via environment variables:

```ruby
SCOPE_PATTERN='-api$' MAX_PAGES=10 SHOTS_DIR=shots bundle exec vessel start serpapi.com
```

- `START_URL` — where the crawl begins (default `https://serpapi.com/`)
- `SCOPE_PATTERN` — regex matched against URL paths (default `-api$`,
  SerpApi's API landing pages); set it empty to scope by the start URL's
  path prefix instead
- `MAX_PAGES` — page budget for the crawl (default 50)
- `SHOTS_DIR` — output directory (default `shots`)
- `VESSEL_ENV` — `dev` runs a visible Chrome window on one thread, `prod`
  runs headless on two threads and logs to `log/vessel.log` (default `dev`)

## Output

The crawler saves output to `shots/` by default:

- `shots/<page-slug>.png` — full-page screenshot per crawled page
- `shots/index.html` — contact sheet with all screenshots, titles, and links

## Vessel vs Mechanize

Here's the advantage of Vessel 0.3 compared to Mechanize:

- `page` inside a handler is the raw `Ferrum::Page`: the crawler scrolls to
  the bottom so lazy-loaded images render, scrolls back, and calls
  `page.screenshot(full: true)`.
- `blacklist` patterns keep Chrome from loading trackers and widgets, which
  speeds up the crawl and keeps consent banners out of the screenshots.
- `driver :ferrum, headless: true, window_size: [1280, 800], timeout: 30`
  passes options straight to `Ferrum::Browser.new`; it's set per environment
  in `config/environments/` (headful in dev, headless in prod).

## Notes

- Screenshots are heavy; the default budget is 50 pages. Full runs against
  big sites will take a while and use real bandwidth.
- Chrome cannot capture extremely tall pages as a single full-page bitmap (it
  hits a texture size limit) and very long captures can exceed the timeout.
  The crawler falls back to a viewport screenshot for those pages and logs a
  warning.
- URL scoping keeps the crawl on the start URL's host, and either matching
  `SCOPE_PATTERN` (default) or under its path prefix when the pattern is
  empty. URLs are normalized
  (fragments and query strings stripped, trailing slashes dropped) and asset
  URLs (images, CSS, feeds, ...) are skipped.
