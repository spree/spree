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
  BUNDLE_GEMFILE=../Gemfile bundle exec rake test_app
}
# Target postgres. Override with: `DB=sqlite bash build.sh`
export DB=${DB:-postgres}

# Spree defaults
echo "Setup Spree defaults..."
bundle check || bundle update --quiet

# Spree API
echo "**************************************"
echo "* Setup Spree API and running RSpec..."
echo "**************************************"
cd api; prepare_app; bundle exec rspec spec

# Spree Backend
echo "******************************************"
echo "* Setup Spree Backend and running RSpec..."
echo "******************************************"
cd ../backend; prepare_app; bundle exec rspec spec

# Spree Core
echo "***************************************"
echo "* Setup Spree Core and running RSpec..."
echo "***************************************"
cd ../core; prepare_app; bundle exec rspec spec

# Spree Frontend
echo "*******************************************"
echo "* Setup Spree Frontend and running RSpec..."
echo "*******************************************"
cd ../frontend; prepare_app; bundle exec rspec spec

# Spree Sample
echo "*****************************************"
echo "* Setup Spree Sample and running RSpec..."
echo "*****************************************"
cd ../sample; prepare_app; bundle exec rspec spec

