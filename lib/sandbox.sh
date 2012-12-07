# Used in the sandbox rake task in Rakefile
#!/bin/bash
rm -rf sandbox
rails new sandbox --skip-bundle
cd sandbox
echo "gem 'spree', :path => '..'" >> Gemfile
echo "gem 'spree_auth_devise', :github => 'spree/spree_auth_devise', :branch => 'edge'" >> Gemfile
bundle install --gemfile Gemfile
rails g spree:install --auto-accept --user_class=Spree::User
