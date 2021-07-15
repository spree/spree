---
title: Upgrading Spree 4.2 to 4.3
section: upgrades
order: 0
hidden: true
---

This guide covers upgrading a **4.2 Spree application** to **Spree 4.3**.

If you have any questions or suggestions feel free to reach out through [Spree slack channels](http://slack.spreecommerce.org/)

**If you're on an older version than 4.1 please follow previous upgrade guides and perform those upgrades incrementally**, eg.

1. [upgrade 3.7 to 4.0](/developer/upgrades/three-dot-seven-to-four-dot-oh.html)
2. [upgrade 4.0 to 4.1](/developer/upgrades/four-dot-oh-to-four-dot-one.html)
3. [upgrade 4.1 to 4.2](/developer/upgrades/four-dot-one-to-four-dot-two.html)

This is the safest and recommended method.

## Update Gemfile

```ruby
gem 'spree', '~> 4.3'
```

## Remove SpreeMultiDomain (optional)

If you used that gem in the past you need to remove it. 

Multi Store is now incorporated into Spree core and you cannot use that gem anymore.

1. Remove `spree_multi_domain` from your `Gemfile`
2. Remove `//= require spree/frontend/spree_multi_domain` from `vendor/assets/javascripts/spree/frontend/all.js`
3. Remove `//= require spree/backend/spree_multi_domain` from `vendor/assets/javascripts/spree/backend/all.js`

## Add `spree_frontend` gem (optional)

`spree` gem now does not include the `spree_frontend` gem anymore. If you use the default Spree Storefront you need to add it to your `Gemfile`.

```ruby
gem 'spree_frontend'
```

## Add `spree_backend` gem (optional)

`spree` gem now does not include the `spree_backend` gem anymore. If you use the default Spree Admin Panel you need to add it to your `Gemfile`.

```ruby
gem 'spree_backend'
```

## Add `spree_emails` gem (optional)

Transactional emails once part of `spree_core` were extracted into their own gem called `spree_emails`. If you would like to still use this feature you'll need to include this new gem in your `Gemfile`.

```ruby
gem 'spree_emails'
```

## Update gems

```bash
bundle update
```

## Install missing migrations

```bash
rails spree:install:migrations
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

## Read the release notes

For information about changes contained within this release, please read the [4.3.0 Release Notes](https://guides.spreecommerce.org/release_notes/spree_4_3_0.html).

## More info

If you have any questions or suggestions feel free to reach out through [Spree slack channels](http://slack.spreecommerce.org/)
