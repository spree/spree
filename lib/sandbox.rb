# Used in the sandbox rake task in Rakefile
gem('spree', :path => "..")
puts "Running Spree installer..."
generate("spree:install --auto-accept")
puts "Precompiling assets..."
rake("assets:precompile:nondigest")
puts "Done!"

