---
title: Upgrading Spree 4.1 to 4.2
section: upgrades
order: 0
---

This guide covers upgrading a **4.1 Spree application** to **Spree 4.2**.

If you have any questions or suggestions feel free to reach out through [Spree slack channels](http://slack.spreecommerce.org/)

**If you're on an older version than 4.1 please follow previous upgrade guides and perform those upgrades incrementally**, eg.

1. [upgrade 3.7 to 4.0](/developer/upgrades/three-dot-seven-to-four-dot-oh.html)
2. [upgrade 4.0 to 4.1](/developer/upgrades/four-dot-oh-to-four-dot-one.html)

This is the safest and recommended method.

## Update Gemfile

```ruby
gem 'spree', '~> 4.2.0.rc4'
gem 'spree_auth_devise', '~> 4.3'
gem 'spree_gateway', '~> 3.9'
```

## Update gems

```
bundle update
```

## Fix RMA migration

Please find a `add_stock_location_to_rma` migration in your `db/migrate` directory and change:

```ruby
class AddStockLocationToRma < ActiveRecord::Migration[4.2]
```

to

```ruby
class AddStockLocationToRMA < ActiveRecord::Migration[4.2]
```

## Install missing migrations

```bash
rails spree:install:migrations
rails active_storage:update
```

## Run migrations

```bash
rails db:migrate
```

## Other things to remember

### Replace `fast_json` with `jsonapi-serializer`

Please follow [this guide to migrate your custom serializers](https://github.com/jsonapi-serializer/jsonapi-serializer#migrating-from-netflixfast_jsonapi).

### Migrate select2 3.5 to 4.x

Only if you've added new Admin Panel pages with Select2 dropdown - [this guide will help](https://select2.org/upgrading/migrating-from-35)

## Read the release notes

For information about changes contained within this release, please read the [4.2.0 Release Notes](https://guides.spreecommerce.org/release_notes/spree_4_2_0.html).

## More info

If you have any questions or suggestions feel free to reach out through [Spree slack channels](http://slack.spreecommerce.org/)
