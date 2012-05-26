# Used in the sandbox rake task in Rakefile
gem('spree', :path => "..")
gem('spree_auth_devise', :path => "~/Sites/gems/spree_auth_devise")
gem('devise-encryptable', '0.1.1')
puts "Running Spree installer..."
generate("spree:install --auto-accept")
puts "Precompiling assets..."
rake("assets:precompile:nondigest")
puts "Done!"

