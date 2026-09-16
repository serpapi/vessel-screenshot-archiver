# frozen_string_literal: true

# Development: a visible Chrome window, one thread, and an extra Debug
# middleware that echoes every capture to the console.
class ApplicationCrawler < Vessel::Cargo
  driver :ferrum, headless: false, window_size: [1280, 800], timeout: 30
  threads max: 1
  middleware "Debug", "CollectShot"
end
