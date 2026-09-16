# Screenshot archiver (Vessel 0.3 + Chrome example)

Companion example for the blog post "Vessel 0.3: Ruby finally gets its Scrapy",
showing the Ferrum (real Chrome) driver. See `../vessel-ruby-crawling/` for the
plain-HTTP Mechanize example.

Crawls a site scoped to the start URL's host and path prefix, renders every
page in headless Chrome, and saves a full-page screenshot per page plus an
`index.html` contact sheet. Useful as a visual archive before a redesign, for
eyeballing a whole site at once, or for visual regression checks.

## Requirements

Chrome or Chromium installed (the Ferrum driver finds it automatically on
macOS; otherwise it must be in `PATH`).

## Usage

```
bundle install

# Screenshot SerpApi's API feature pages (they share no path prefix,
# so scope by regex instead of by path):
SCOPE_PATTERN='-api$' MAX_PAGES=10 bundle exec ruby screenshot_archiver.rb https://serpapi.com/

# Or scope by path prefix, like the crosslink mapper example:
bundle exec ruby screenshot_archiver.rb https://serpapi.com/blog/

open shots/index.html
```

Options via environment variables:

```
SCOPE_PATTERN='-api$' MAX_PAGES=10 THREADS=2 SHOTS_DIR=shots bundle exec ruby screenshot_archiver.rb https://serpapi.com/
```

- `SCOPE_PATTERN` — regex matched against URL paths; overrides the default
  path-prefix scoping
- `MAX_PAGES` — page budget for the crawl (default 50)
- `THREADS` — thread pool size, one Chrome page each (default 2)
- `SHOTS_DIR` — output directory (default `shots`)

## Output

- `shots/<page-slug>.png` — full-page screenshot per crawled page
- `shots/index.html` — contact sheet with all screenshots, titles, and links

## What it demonstrates that Mechanize can't

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
- URL scoping and normalization match the crosslink mapper example: fragments
  and query strings stripped, trailing slashes dropped, assets skipped.
