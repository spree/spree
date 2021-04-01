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
gem 'spree', '~> 4.2'
gem 'spree_auth_devise', '~> 4.3'
gem 'spree_gateway', '~> 3.9'
gem 'spree_i18n', '~> 5.0'
```

## Remove SpreeMultiCurrency (optional)

If you used that gem in the past you need to remove. Multi Currency is now incorporated into Spree core and you cannot use that gem anymore.

1. Remove `spree_multi_currency` from your `Gemfile`
2. Remove these preferences from your Spree initializer (`config/initializers/spree.rb`):

      * `allow_currency_change`
      * `show_currency_selector`
      * `supported_currencies`
3. Remove `//= require spree/frontend/spree_multi_currency` from `vendor/assets/javascripts/spree/frontend/all.js`
4. Remove `//= require spree/backend/spree_multi_currency` from `vendor/assets/javascripts/spree/backend/all.js`

## Add `deface` gem (optional)

If you used [Deface overrides](/developer/advanced/deface_overrides_tutorial.html) you will need to include `deface` in your `Gemfile` as it was removed from Spree / Spree Auth Devise / Spree Gateway dependencies.

Simply add it to your `Gemfile`:

```ruby
gem 'deface'
```

## Update gems

```bash
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

## Upgrade all of your Spree extensions to the newest versions

To avoid errors and compatibility issues, please update all of your Spree extension gems to the newest versions which usually includes fixes for the new Spree release, eg.

```bash
bundle update spree_related_products
```

## Other things to remember

### Replace `fast_json` with `jsonapi-serializer`

Please follow [this guide to migrate your custom serializers](https://github.com/jsonapi-serializer/jsonapi-serializer#migrating-from-netflixfast_jsonapi).

### Migrate select2 3.5 to 4.x

Only if you've added new Admin Panel pages with Select2 dropdown - [this guide will help](https://select2.org/upgrading/migrating-from-35)

### Make sure you've got up to date Spree templates (Storefront)

If you're using Spree default Storefront (`spree_frontend` gem) make sure to update your templates, especially:

* [app/views/spree/shared/_head.html.erb](https://github.com/spree/spree/blob/4-2-stable/frontend/app/views/spree/shared/_head.html.erb)
* [app/views/spree/shared/_locale_and_currency.html.erb](https://github.com/spree/spree/blob/4-2-stable/frontend/app/views/spree/shared/_locale_and_currency.html.erb)
* [app/views/spree/shared/_link_to_account.html.erb](https://github.com/spree/spree/blob/4-2-stable/frontend/app/views/spree/shared/_link_to_account.html.erb)
* [app/views/spree/shared/_internationalization_options.html.erb](https://github.com/spree/spree/blob/master/frontend/app/views/spree/shared/_internationalization_options.html.erb)
* [app/views/spree/shared/_locale_dropdown.html.erb](https://github.com/spree/spree/blob/4-2-stable/frontend/app/views/spree/shared/_locale_dropdown.html.erb)
* [app/views/spree/shared/_currency_dropdown.html.erb](https://github.com/spree/spree/blob/4-2-stable/frontend/app/views/spree/shared/_currency_dropdown.html.erb)
* [app/views/spree/shared/_mobile_navigation.html.erb](https://github.com/spree/spree/blob/4-2-stable/frontend/app/views/spree/shared/_mobile_navigation.html.erb)
* [app/views/spree/shared/_mobile_internationalization_options.html.erb](https://github.com/spree/spree/blob/4-2-stable/frontend/app/views/spree/shared/_mobile_internationalization_options.html.erb)
* [app/views/spree/shared/_nav_bar.html.erb](https://github.com/spree/spree/blob/4-2-stable/frontend/app/views/spree/shared/_nav_bar.html.erb)
* [app/views/spree/shared/_line_item.html.erb](https://github.com/spree/spree/blob/4-2-stable/frontend/app/views/spree/shared/_line_item.html.erb)

Or simply run `bundle exec rails g spree:frontend:copy_storefront`

## Read the release notes

For information about changes contained within this release, please read the [4.2.0 Release Notes](https://guides.spreecommerce.org/release_notes/spree_4_2_0.html).

## More info

If you have any questions or suggestions feel free to reach out through [Spree slack channels](http://slack.spreecommerce.org/)
