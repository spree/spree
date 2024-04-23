#!/bin/sh
# Used in the sandbox rake task in Rakefile

set -e

case "$DB" in
mysql)
  RAILSDB="mysql"
  ;;
postgres)
  RAILSDB="postgresql"
  ;;
sqlite|'')
  RAILSDB="sqlite3"
  ;;
*)
  echo "Invalid DB specified: $DB"
  exit 1
  ;;
esac

rm -rf ./sandbox
bundle exec rails new sandbox --database="$RAILSDB" \
  --skip-bundle \
  --skip-git \
  --skip-keeps \
  --skip-rc \
  --skip-test \

if [ ! -d "sandbox" ]; then
  echo 'sandbox rails application failed'
  exit 1
fi

cd ./sandbox

git submodule update --init --recursive

cat <<RUBY >> Gemfile
gem 'spree', path: '..'
gem 'spree_emails', path: '../emails'
gem 'spree_sample', path: '../sample'
gem 'spree_backend', path: '../backend'
gem 'spree_frontend', path: '../frontend'
gem 'spree_auth_devise', path: '../auth_devise'
gem 'spree_gateway', path: '../gateway'
gem 'spree_i18n', github: 'spree-contrib/spree_i18n', branch: 'main'

group :test, :development do
  gem 'bullet'
  gem 'pry-byebug'
  gem 'awesome_print'
end

# temporary fix for sassc segfaults on ruby 3.0.0 on Mac OS Big Sur
# this change fixes the issue:
# https://github.com/sass/sassc-ruby/commit/04407faf6fbd400f1c9f72f752395e1dfa5865f7
gem 'sassc', github: 'sass/sassc-ruby', branch: 'master'
RUBY

touch config/initializers/bullet.rb

cat <<RUBY >> config/initializers/bullet.rb
if Rails.env.development? && defined?(Bullet)
  Bullet.enable = true
  Bullet.rails_logger = true
  Bullet.stacktrace_includes = [ 'spree_core', 'spree_frontend', 'spree_api', 'spree_backend', 'spree_emails' ]
end
RUBY

bundle update
bundle install --gemfile Gemfile

bin/rails importmap:install
bin/rails turbo:install
bin/rails stimulus:install

bin/rails db:drop || true
bin/rails db:create
bin/rails g spree:install --auto-accept --user_class=Spree::User --sample=true
bin/rails g spree:backend:install
bin/rails g spree:frontend:install
bin/rails g spree:emails:install
bin/rails g spree:auth:install
bin/rails g spree_gateway:install
