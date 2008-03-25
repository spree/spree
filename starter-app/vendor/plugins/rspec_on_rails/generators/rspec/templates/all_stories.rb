dir = File.dirname(__FILE__)
Dir[File.expand_path("#{dir}/**/*.rb")].uniq.each do |file|
  require file
end