gem "spree", :path => File.dirname(__FILE__)

gem 'mysql'
gem 'sqlite3-ruby'
gem 'ruby-debug'

# eventually these can be dropped and replaced by spree.gemspec dependencies but we need the edge versions for now
gem "activemerchant", :require => 'active_merchant', :git => "git://github.com/railsjedi/active_merchant.git"
gem "will_paginate", :git => "git://github.com/mislav/will_paginate.git", :branch => "rails3"
gem 'resource_controller', :git => "git://github.com/BDQ/resource_controller.git"