#!/bin/sh

set -e

# Switching Gemfile
set_gemfile(){
  echo "Switching Gemfile..."
  export BUNDLE_GEMFILE="`pwd`/Gemfile"
}

prepare_app(){
  set_gemfile
  bundle update --quiet
  echo "Preparing test app..."
  bundle exec rake test_app
}
# Target postgres. Override with: `DB=mysql bash bin/build.sh`
export DB=${DB:-postgres}

# Spree defaults
echo "Setup Spree defaults..."
bundle check || bundle update --quiet

# Spree API
echo "**************************************"
echo "* Setup Spree API and running RSpec..."
echo "**************************************"
cd ../api; prepare_app; bundle exec rspec spec

# Spree Core
echo "***************************************"
echo "* Setup Spree Core and running RSpec..."
echo "***************************************"
cd ../core; prepare_app; bundle exec rspec spec

# Spree Emails
echo "*******************************************"
echo "* Setup Spree Emails and running RSpec..."
echo "*******************************************"
cd ../emails; prepare_app; bundle exec rspec spec

# Spree Sample
echo "*******************************************"
echo "* Setup Spree Sample and running RSpec..."
echo "*******************************************"
cd ../sample; prepare_app; bundle exec rspec spec

