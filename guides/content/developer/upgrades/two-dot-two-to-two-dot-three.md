---
title: Upgrading Spree from 2.2.x to 2.3.x
section: upgrades
---

## Overview

This guide covers upgrading a 2.2.x Spree store, to a 2.3.x store. This
guide has been written from the perspective of a blank Spree 2.2.x store with
no extensions.

If you have extensions that your store depends on, you will need to manually
verify that each of those extensions work within your 2.3.x store once this
upgrade is complete. Typically, extensions that are compatible with this
version of Spree will have a 2-3-stable branch.

This is the first Spree release which supports Rails 4.1.

## Upgrade Rails

For this Spree release, you will need to upgrade your Rails version to at least 4.1.2.

```ruby
gem 'rails', '~> 4.1.2'
```

## Upgrade Spree

For best results, use the 2-3-stable branch from GitHub:

```ruby
gem 'spree', github: 'spree/spree', branch: '2-3-stable'```

Run `bundle update spree`.

## Copy and run migrations

Copy over the migrations from Spree (and any other engine) and run them using
these commands:

    rake railties:install:migrations
    rake db:migrate

## Read the release notes

For information about changes contained with this release, please read the [2.3.0 Release Notes](http://guides.spreecommerce.org/release_notes/spree_2_3_0.html).

## Verify that everything is OK

Click around in your store and make sure it's performing as normal. Fix any deprecation warnings you see.
