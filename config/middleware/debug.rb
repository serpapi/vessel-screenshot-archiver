# frozen_string_literal: true

# Echo every capture in development.
class Debug < Vessel::Middleware
  def call(hash, _fields)
    puts "#{hash[:url]} -> #{hash[:file]}"
    hash
  end
end
