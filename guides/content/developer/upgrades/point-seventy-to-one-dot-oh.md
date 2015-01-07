---
title: Upgrading Spree from 0.70.x to 1.0.x
section: upgrades
---

## Overview

This guide covers upgrading a 0.70.x Spree store, to a 1.0.x store. This
guide has been written from the perspective of a blank Spree 0.70.x store with
no extensions.

If you have extensions that your store depends on, you will need to manually
verify that each of those extensions work within your 1.0.x store once this
upgrade is complete. Typically, extensions that are compatible with this
version of Spree will have a 1-0-stable branch.

Worth noting here is that Spree 1.0 was the first release to properly use the
features of Rails engines. This means that Spree needs to be mounted manually
within the `config/routes.rb` file of the application, and that the classes
such as `Product` and `Variant` from Spree are now namespaced within a module,
so that they are now `Spree::Product` and `Spree::Variant`. Tables are
similarly namespaced (i.e. `spree_products` and `spree_variants`).

Along with this, migrations must be copied over to the application using the
`rake railties:install:migrations` command, rather than a `rails g spree:site`
command as before.

## Upgrade Rails

Spree 1.0 depends on any Rails 3.1 release afer Rails 3.1.10. Ensure that you have that dependency specified in your Gemfile:

```ruby
gem 'rails', '~> 3.1.10'

## Upgrade Spree

For best results, use the 1-0-stable branch from GitHub:

```ruby
gem 'spree', :github => 'spree/spree', :branch => '1-0-stable'```

Run `bundle update spree`. 

## Rename middleware classes

In `config/application.rb`, there are two pieces of middleware:

```ruby
config.middleware.use "RedirectLegacyProductUrl"
config.middleware.use "SeoAssist"```

These classes are now namespaced within Spree:

```ruby
config.middleware.use "Spree::Core::Middleware::RedirectLegacyProductUrl"
config.middleware.use "Spree::Core::Middleware::SeoAssist"```


## Copy and run migrations

Copy over the migrations from Spree (and any other engine) and run them using
these commands:

    rake railties:install:migrations
    rake db:migrate

## Mount the Spree engine

Within `config/routes.rb`, you must now mount the Spree engine:

```ruby
mount Spree::Core::Engine, :at => '/'```

This is the standard way of adding engines to Rails applications.

## Remove spree_dash assets

Spree's dash component was removed as a dependency of Spree, and so references
to its assets must be removed also. Remove references to spree_dash from:

* app/assets/stylesheets/store/all.css
* app/assets/javascripts/store/all.js
* app/assets/stylesheets/admin/all.css
* app/assets/javascripts/admin/all.js

## Verify that everything is OK

Click around in your store and make sure it's performing as normal. Fix any deprecation warnings you see.
