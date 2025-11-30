#!/bin/bash
set -e

echo "Setting up Spree development environment..."

# Install Ruby dependencies
echo "Installing Ruby dependencies..."
bundle install

# Create sandbox application for development
echo "Creating sandbox application..."
if [ ! -d "sandbox" ] || [ ! -f "sandbox/Gemfile.lock" ]; then
  bundle exec rake sandbox
fi

echo ""
echo "========================================"
echo "Spree development environment is ready!"
echo "========================================"
echo ""
echo "Quick start commands:"
echo "  cd sandbox && bin/dev   # Start the sandbox app"
echo "  bundle exec rake test_app         # Create test apps for all gems"
echo "  cd core && bundle exec rspec      # Run core gem tests"
echo ""
echo "Database: SQLite"
echo ""
