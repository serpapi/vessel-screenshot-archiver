# frozen_string_literal: true

# Production: headless Chrome, two pages in parallel, and logs to a file
# instead of stdout.
Vessel::Logger.instance = Logger.new("log/vessel.log", level: Logger::INFO)

class ApplicationCrawler < Vessel::Cargo
  driver :ferrum, headless: true, window_size: [1280, 800], timeout: 30
  threads max: 2
  middleware "CollectShot"
end
