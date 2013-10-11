---
title: Upgrading Spree from 1.2.x to 1.3.x
section: upgrades
---

This guide covers upgrading a 1.2.x Spree store, to a 1.3.x store. This
guide has been written from the perspective of a blank Spree 1.2.x store with
no extensions.

If you have extensions that your store depends on, you will need to manually
verify that each of those extensions work within your 1.3.x store once this
upgrade is complete. Typically, extensions that are compatible with this
version of Spree will have a 1-3-stable branch.

## Upgrade Spree

For best results, use the 1-3-stable branch from GitHub:

```ruby
gem 'spree', :github => 'spree/spree', :branch => '1-3-stable'```

Run `bundle update spree`. 

## Bump jquery-rails

This version of Spree bumps the dependency for jquery-rails to this:

```ruby
gem 'jquery-rails', '2.2.0'```

Ensure that you have a line such as this in your Gemfile to allow that dependency.

## Copy and run migrations

Copy over the migrations from Spree (and any other engine) and run them using
these commands:

    rake railties:install:migrations
    rake db:migrate

## Read the release notes

For information about changes contained with this release, please read the [1.3.0 Release Notes](http://guides.spreecommerce.com/release_notes/spree_1_3_0.html).

## Verify that everything is OK

Click around in your store and make sure it's performing as normal. Fix any deprecation warnings you see.