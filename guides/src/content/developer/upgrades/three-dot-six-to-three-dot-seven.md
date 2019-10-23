---
title: Upgrading Spree from 3.6 to 3.7
section: upgrades
order: 0
---

This guide covers upgrading a 3.6 Spree application, to version 3.7.

### Update Gemfile

```ruby
gem 'spree', '~> 3.7.0'
gem 'spree_auth_devise', '~> 3.5'
gem 'spree_gateway', '~> 3.4'
```

### Run `bundle update`

### Install missing migrations

```bash
rails spree:install:migrations
rails spree_api:install:migrations
rails spree_auth:install:migrations
rails spree_gateway:install:migrations
```

### Run migrations

```bash
rails db:migrate
```

### Migrate Taxon icons to Spree Assets

We renamed `TaxonIcon` to `TaxonImage` to clarify usage of this model.
If you were using `TaxonIcon` please run this to migrate your icons to images:

```bash
rails db:migrate_taxon_icons_to_images
```

### Ensure all Orders associated to Store

Orders needs to be associated to Stores.
To ensure all existing `Order` are associated with `Store` please run this:

```bash
rails db:associate_orders_with_store
```

This will associate all Orders without Store to the default Store.
This can take some time depending on your volume of data.

### Ensure all Orders have currency present

To enhance multi currency capabilities we've made `currency` presence
obligatory in `Order` model. To ensure all existing `Orders` have `currency`
present please run this command:

```bash
rails db:ensure_order_currency_presence
```

This will set `currency` in Orders without currency set to `Spree::Config[:default_currency]` value. This can take some time depending on your volume of data.

### Replace `guest_token` with `token` in your codebase

`Order#guest_token` was renamed to `Order#token` in order to unify the experience for guest checkouts and orders placed by signed in users.

### Read the release notes

For information about changes contained within this release, please read the [3.7.0 Release Notes](https://guides.spreecommerce.org/release_notes/spree_3_7_0.html).
