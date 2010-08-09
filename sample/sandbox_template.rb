#File.open("Gemfile", 'w') { |f| }
# IMPORTANT: __FILE__ refer to (eval), not to sandbox_template.rb !!!
gem "spree", :path => ".."

gem 'rspec', '2.0.0.beta.19', :group => 'test'
gem 'rspec-rails', '2.0.0.beta.19', :group => 'test'