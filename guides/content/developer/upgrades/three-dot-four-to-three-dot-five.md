---
title: Upgrading Spree from 3.4.x to 3.5.x
section: upgrades
---

This guide covers upgrading a 3.4 Spree store, to a 3.5 store.

### Update Gemfile

```ruby
gem 'spree', '~> 3.5.0'
gem 'spree_auth_devise', '~> 3.3'
gem 'spree_gateway', '~> 3.3'
```

### Run `bundle update`

### Install missing migrations

```bash
rails spree:install:migrations
rails spree_auth:install:migrations
rails spree_gateway:install:migrations
```

### Run migrations

```bash
rails db:migrate
```

### Install Spree Analytics Trackers

If you used analytics trackers from spree, you have to install gem
spree_analytics_trackers from [Spree Analytics Trackers](https://github.com/spree-contrib/spree_analytics_trackers).

## Read the release notes

For information about changes contained within this release, please read the [3.5.0 Release Notes](http://guides.spreecommerce.org/release_notes/spree_3_5_0.html).

## Verify that everything is OK

Run you test suite, click around in your store and make sure it's performing as normal. Fix any deprecation warnings you see.
