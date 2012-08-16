# Used in the sandbox rake task in Rakefile
#!/bin/bash
rm -rf sandbox
rails new sandbox --skip-bundle
cd sandbox
echo "gem 'spree', :path => '..'\n" >> Gemfile
echo "gem 'spree_auth_devise', :git => 'git://github.com/spree/spree_auth_devise'\n" >> Gemfile
bundle install --gemfile Gemfile
rails g spree:install --auto-accept --user_class=Spree::User
