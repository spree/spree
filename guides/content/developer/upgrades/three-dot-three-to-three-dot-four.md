---
title: Upgrading Spree from 3.3.x to 3.4.x
section: upgrades
---

This guide covers upgrading a 3.3 Spree store, to a 3.4 store.

### Update Gemfile

```ruby
gem 'spree', '~> 3.4.0'
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

### Migrate Spree::Taxon icons to Spree Assets

We changed `Spree::Taxon` icon to use `Spree::Asset` to unify attachment usage
across all Spree models. If you were using icon images in `Spree::Taxon`
please run this to migrate your icons:

```bash
rails db:migrate_taxon_icons
```

## Read the release notes

For information about changes contained within this release, please read the [3.4.0 Release Notes](http://guides.spreecommerce.org/release_notes/spree_3_4_0.html).

## Verify that everything is OK

Run you test suite, click around in your store and make sure it's performing as normal. Fix any deprecation warnings you see.
