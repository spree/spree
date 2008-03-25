dir = File.dirname(__FILE__)
Dir["#{dir}/**/*_example.rb"].each do |file|
  require file
end
Dir["#{dir}/**/*_spec.rb"].each do |file|
  require file
end
