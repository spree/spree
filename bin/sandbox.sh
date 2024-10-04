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

cat <<RUBY >> Gemfile
gem 'spree', path: '..'
gem 'spree_emails', path: '../emails'
gem 'spree_sample', path: '../sample'
gem 'spree_admin', path: '../admin'
gem 'spree_auth_devise', github: 'spree/spree_auth_devise', branch: 'main'
gem 'spree_gateway', github: 'spree/spree_gateway', branch: 'main'
gem 'spree_i18n', github: 'spree-contrib/spree_i18n', branch: 'main'

group :test, :development do
  gem 'bullet'
  gem 'pry-byebug'
  gem 'awesome_print'
end
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
bin/rails g spree:emails:install
bin/rails g spree:admin:install
bin/rails g spree:auth:install
bin/rails g spree_gateway:install
bin/rake acts_as_taggable_on_engine:install:migrations
