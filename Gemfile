source :gemcutter

gem "spree", :path => File.dirname(__FILE__)

# eventually these can be dropped and replaced by spree.gemspec dependencies but we need the edge versions for now
gem "activemerchant", :require => 'active_merchant', :git => "git://github.com/railsjedi/active_merchant.git"
gem "will_paginate", :git => "git://github.com/mislav/will_paginate.git", :branch => "rails3"
gem 'resource_controller', :git => "git://github.com/BDQ/resource_controller.git"
gem "authlogic", '>= 2.1.5'

gem 'searchlogic', :git => 'git://github.com/romul/searchlogic.git'

gem 'mysql'
gem 'sqlite3-ruby'
gem 'ruby-debug'
gem "rdoc",  "2.2"

group :test do
  gem 'shoulda', :git => "git://github.com/thoughtbot/shoulda.git"
  gem 'factory_girl_rails', '>= 1.0.0'
  gem 'spork'
  #gem 'test-unit', '~>2.0.5', :require => 'test/unit' if RUBY_VERSION.to_f >= 1.9
  gem 'faker'
end

# group :cucumber do
#   gem 'cucumber-rails', '>=0.2.4', :require => false
#   gem 'database_cleaner', '>=0.4.3', :require => false
#   gem 'capybara', '>=0.3.0', :require => false
#   gem 'spork', '>=0.7.5', :require => false
#   gem 'factory_girl', '1.2.3', :require => false
#   gem 'pickle', '0.2.1', :require => false
#   gem 'rack-test', '>=0.5.4', :require => false
# end
