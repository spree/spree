source :gemcutter

gem 'rails', '3.0.0.beta4'
gem 'mysql'          

gem 'highline', '1.5.1'
gem 'authlogic','>=2.1.5'
gem 'authlogic-oid', '1.0.4', :require => 'authlogic_openid'
gem "activemerchant", :require => 'active_merchant', :git => "git://github.com/railsjedi/active_merchant.git"
gem 'activerecord-tableless', '0.1.0', :require => 'tableless'
gem 'less', '1.2.20'
gem 'stringex', '1.0.3', :require => 'stringex'
gem 'chronic', '0.2.3'
gem 'whenever', '0.3.7', :require => false
gem 'will_paginate', '2.3.14', :require => 'will_paginate'
gem 'state_machine', '0.8.0', :require => 'state_machine'
gem 'faker', '0.3.1'
gem 'paperclip', '>=2.3.1.1'
gem 'ruby-openid', '>=2.0.4', :require => 'openid'
gem 'resource_controller', :git => "git://github.com/BDQ/resource_controller.git"
# gem 'find_by_param'

gem 'ruby-debug'

group :test do
  gem 'shoulda', '2.10.2', :require => 'shoulda'
  gem 'factory_girl', '1.2.3', :require => 'factory_girl'
  gem 'test-unit', '~>2.0.5', :require => 'test/unit' if RUBY_VERSION.to_f >= 1.9
end

group :cucumber do
  gem 'cucumber-rails', '>=0.2.4', :require => false
  gem 'database_cleaner', '>=0.4.3', :require => false
  gem 'capybara', '>=0.3.0', :require => false
  gem 'spork', '>=0.7.5', :require => false
  gem 'factory_girl', '1.2.3', :require => false
  gem 'pickle', '0.2.1', :require => false
  gem 'rack-test', '>=0.5.4', :require => false
end