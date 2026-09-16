# frozen_string_literal: true

require "cgi"
require "uri"

# Thread-safe store for captured pages and the contact sheet writer.
module Gallery
  @pages = []
  @lock = Mutex.new

  class << self
    def add(hash)
      @lock.synchronize { @pages << hash }
    end

    def write_contact_sheet(start_url:, budget:)
      pages = @lock.synchronize { @pages.sort_by { |p| p[:url] } }

      if pages.empty?
        puts "No pages captured. Is #{start_url} reachable?"
        return
      end

      cards = pages.map do |p|
        name = File.basename(p[:file])
        title = CGI.escapeHTML(p[:title].to_s)
        path = CGI.escapeHTML(URI(p[:url]).path)

        <<~CARD
          <figure>
            <a href="#{name}"><img src="#{name}" loading="lazy" alt="#{title}"></a>
            <figcaption><strong>#{title}</strong><br><a href="#{CGI.escapeHTML(p[:url])}">#{path}</a></figcaption>
          </figure>
        CARD
      end.join

      File.write(File.join(AppSettings::SHOTS_DIR, "index.html"), <<~HTML)
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <title>Screenshots of #{CGI.escapeHTML(start_url)}</title>
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
          <h1>#{pages.size} pages under #{CGI.escapeHTML(start_url)}</h1>
          <main>#{cards}</main>
        </body>
        </html>
      HTML

      puts "Captured #{pages.size} pages (budget: #{budget}) into #{AppSettings::SHOTS_DIR}/"
      puts "Contact sheet: open #{File.join(AppSettings::SHOTS_DIR, "index.html")}"
    end
  end
end
