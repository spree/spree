#!/bin/sh

set -e

# Switching Gemfile
set_gemfile(){
  echo "Switching Gemfile..."
  export BUNDLE_GEMFILE="`pwd`/Gemfile"
}

# Target postgres. Override with: `DB=sqlite bash build.sh`
export DB=${DB:-postgres}

# Spree defaults
echo "Setup Spree defaults and creating test application..."
bundle check || bundle update
bundle exec rake test_app

# Spree API
echo "Setup Spree API and running RSpec..."
cd api; set_gemfile; bundle update; bundle exec rspec spec

# Spree Backend
echo "Setup Spree Backend and running RSpec..."
cd ../backend; set_gemfile; bundle update; bundle exec rspec spec

# Spree Core
echo "Setup Spree Core and running RSpec..."
cd ../core; set_gemfile; bundle update; bundle exec rspec spec

# Spree Frontend
echo "Setup Spree Frontend and running RSpec..."
cd ../frontend; set_gemfile; bundle update; bundle exec rspec spec

# Spree Sample
echo "Setup Spree Sample and running RSpec..."
cd ../sample; bundle install; bundle exec rake test_app; bundle exec rspec spec
