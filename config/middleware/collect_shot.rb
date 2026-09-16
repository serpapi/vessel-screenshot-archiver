# frozen_string_literal: true

# Adds every captured page to the gallery the contact sheet is built
# from after the crawl.
class CollectShot < Vessel::Middleware
  def call(hash, _fields)
    Gallery.add(hash)
    hash
  end
end
