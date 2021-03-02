#!/bin/sh
# Used in the sandbox rake task in Rakefile

set -e

case "$DB" in
postgres)
  RAILSDB="postgresql"
  ;;
mysql)
  RAILSDB="mysql"
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
  --skip-spring \
  --skip-test \
  --skip-coffee \
  --skip-javascript \
  --skip-bootsnap

if [ ! -d "sandbox" ]; then
  echo 'sandbox rails application failed'
  exit 1
fi

cd ./sandbox

if [ "$SPREE_AUTH_DEVISE_PATH" != "" ]; then
  SPREE_AUTH_DEVISE_GEM="gem 'spree_auth_devise', path: '$SPREE_AUTH_DEVISE_PATH'"
else
  SPREE_AUTH_DEVISE_GEM="gem 'spree_auth_devise', github: 'spree/spree_auth_devise', branch: 'master'"
fi

if [ "$SPREE_GATEWAY_PATH" != "" ]; then
  SPREE_GATEWAY_GEM="gem 'spree_gateway', path: '$SPREE_GATEWAY_PATH'"
else
  SPREE_GATEWAY_GEM="gem 'spree_gateway', github: 'spree/spree_gateway', branch: 'master'"
fi

if [ "$SPREE_HEADLESS" != "" ]; then
cat <<RUBY >> Gemfile
gem 'spree_core', path: '..'
gem 'spree_api', path: '..'
gem 'spree_backend', path: '..'
gem 'spree_sample', path: '..'
gem 'spree_cmd', path: '..'

$SPREE_AUTH_DEVISE_GEM
$SPREE_GATEWAY_GEM

gem 'spree_i18n', github: 'spree-contrib/spree_i18n', branch: 'master'

group :test, :development do
  gem 'bullet'
  gem 'pry-byebug'
  gem 'awesome_print'
end

gem 'rack-cache'
RUBY
else
cat <<RUBY >> Gemfile
gem 'spree', path: '..'
$SPREE_AUTH_DEVISE_GEM
$SPREE_GATEWAY_GEM
gem 'spree_i18n', github: 'spree-contrib/spree_i18n', branch: 'master'
gem 'spree_static_content', github: 'spree-contrib/spree_static_content', branch: 'master'
gem 'spree_related_products', github: 'spree-contrib/spree_related_products', branch: 'master'
gem 'spree_multi_domain', github: 'spree-contrib/spree-multi-domain', branch: 'master'

group :test, :development do
  gem 'bullet'
  gem 'pry-byebug'
  gem 'awesome_print'
end

# ExecJS runtime
gem 'mini_racer'

# temporary fix for sassc segfaults on ruby 3.0.0 on Mac OS Big Sur
# this change fixes the issue:
# https://github.com/sass/sassc-ruby/commit/04407faf6fbd400f1c9f72f752395e1dfa5865f7
gem 'sassc', github: 'sass/sassc-ruby', branch: 'master'

gem 'rack-cache'
RUBY
fi

cat <<RUBY >> config/environments/development.rb
Rails.application.config.hosts << /.*\.lvh\.me/
RUBY

bundle install --gemfile Gemfile
bundle exec rails db:drop || true
bundle exec rails db:create
bundle exec rails g spree:install --auto-accept --user_class=Spree::User --enforce_available_locales=true --copy_storefront=false
bundle exec rails g spree:mailers_preview
bundle exec rails g spree:auth:install
bundle exec rails g spree_gateway:install

if [ "$SPREE_HEADLESS" == "" ]; then
  bundle exec rails g spree_related_products:install
  bundle exec rails g spree_static_content:install
  bundle exec rails g spree_multi_domain:install
fi
