#!/bin/sh

set -e

# Build project
build() {
  export BUNDLE_GEMFILE="`pwd`/Gemfile"
  bundle check || bundle update
  bundle exec rake test_app
  bundle exec rake spec
}

# Target postgres. Override with: `DB=sqlite bash build.sh`
export DB=${DB:-postgres}

# Spree API
echo "Setup Spree API and running RSpec..."
cd api && build

# Spree Backend
echo "Setup Spree Backend and running RSpec..."
cd ../backend && build

# Spree Core
echo "Setup Spree Core and running RSpec..."
cd ../core && build

# Spree Frontend
echo "Setup Spree Frontend and running RSpec..."
cd ../frontend && build

# Spree Sample
echo "Setup Spree Sample and running RSpec..."
cd ../sample && build
