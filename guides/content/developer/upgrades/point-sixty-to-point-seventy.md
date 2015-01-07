---
title: Upgrading Spree from 0.60.x to 0.70.x
section: upgrades
---

## Overview

This guide covers upgrading a 0.60.x Spree store, to a 0.70.x store. This
guide has been written from the perspective of a blank Spree 0.60.x store with
no extensions.

If you have extensions that your store depends on, you will need to manually
verify that each of those extensions work within your 0.70.x store once this
upgrade is complete.

## Upgrade Rails

Spree 0.60.x depends on Rails 3.0.12, whereas Spree 0.70.x depends on any Rails
version from 3.1.1 up to 3.1.4. The first step in upgrading Spree is to
upgrade the Rails version in the `Gemfile`:

```ruby
gem 'rails', '3.1.12'```

For more information, please read the [Upgrading Ruby on Rails Guide](http://guides.rubyonrails.org/upgrading_ruby_on_rails.html#upgrading-from-rails-3-0-to-rails-3-1).

## Upgrade Spree

For best results, use the 0-70-stable branch from GitHub:

```ruby
gem 'spree', :github => 'spree/spree', :branch => '0-70-stable'```

Run `bundle update rails` and `bundle update spree` and verify that was successful.

## Remove debug_rjs configuration

In `config/environments/development.rb`, remove this line:

```ruby
config.action_view.debug_rjs = true```

## Remove lib/spree_site.rb

This file is no longer used in 0.70.x versions of Spree.

## Set up new data

To migrate the data across, use these commands:

```bash
rails g spree:site
rake db:migrate```

## The Asset Pipline

With the upgrade to Rails 3.1 comes the [asset pipeline](http://guides.rubyonrails.org/asset_pipeline.html). You need to add these gems to your Gemfile in order to support Spree's assets being served:

```ruby
group :assets do
  gem 'sass-rails',   '~> 3.1.5'
  gem 'coffee-rails', '~> 3.1.1'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  # gem 'therubyracer'

  gem 'uglifier', '>= 1.0.3'
end

gem 'jquery-rails', '2.2.1'```

Along with these gems, you will need to enable assets within the class definition inside `config/application.rb`:

```ruby
module YourStore
  class Application < Rails::Application

  # ...

  # Enable the asset pipeline
  config.assets.enabled = true

  # Version of your assets, change this if you want to expire all your assets
  config.assets.version = '1.0'
  
  end
end```

## Verify that everything is OK

Click around in your store and make sure it's performing as normal. Fix any deprecation warnings you see.
