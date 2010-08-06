File.open("Gemfile", 'w') { |f| }
gem 'rails', '>=3.0.0.rc'
# IMPORTANT: __FILE__ refer to (eval), not to sandbox_template.rb !!!
gem "spree", :path => ".."

gem 'sqlite3-ruby'
gem 'ruby-debug' if RUBY_VERSION.to_f < 1.9

# Use unicorn as the web server
# gem 'unicorn'

gem "spree_sample", :path => "../sample", :require => ['spree_sample','spree_sample/engine']

remove_file "public/index.html"

append_file "public/robots.txt", <<-ROBOTS
User-agent: *
Disallow: /checkouts
Disallow: /orders
Disallow: /countries
Disallow: /line_items
Disallow: /password_resets
Disallow: /states
Disallow: /user_sessions
Disallow: /users
ROBOTS

append_file "db/seeds.rb", <<-SEEDS
Rake::Task["db:load_dir"].invoke( "default" )
puts "Default data has been loaded"
SEEDS

run "mkdir -p db/migrate"
run "mkdir -p db/default"
run "mkdir -p db/sample/assets"
