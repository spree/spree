---
title: Upgrading Spree from 1.1.x to 1.2.x
section: upgrades
---

This guide covers upgrading a 1.1.x Spree store, to a 1.2.x store. This
guide has been written from the perspective of a blank Spree 1.1.x store with
no extensions.

If you have extensions that your store depends on, you will need to manually
verify that each of those extensions work within your 1.2.x store once this
upgrade is complete. Typically, extensions that are compatible with this
version of Spree will have a 1-2-stable branch.

## Upgrade Spree

For best results, use the 1-2-stable branch from GitHub:

```ruby
gem 'spree', :github => 'spree/spree', :branch => '1-2-stable'```

Run `bundle update spree`. 

## Copy and run migrations

Copy over the migrations from Spree (and any other engine) and run them using
these commands:

    rake railties:install:migrations
    rake db:migrate

## Read the release notes

For information about changes contained with this release, please read the [1.2.0 Release Notes](http://guides.spreecommerce.com/release_notes/spree_1_2_0.html).

## Verify that everything is OK

Click around in your store and make sure it's performing as normal. Fix any deprecation warnings you see.