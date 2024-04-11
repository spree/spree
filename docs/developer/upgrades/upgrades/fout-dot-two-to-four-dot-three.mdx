---
title: Upgrading Spree 4.2 to 4.3
section: upgrades
order: 0
hidden: true
description: This guide covers upgrading a 4.2 Spree application to Spree 4.3.
---

# 4.2 to 4.3

If you have any questions or suggestions feel free to reach out through [Spree slack channels](http://slack.spreecommerce.org/)

**If you're on an older version than 4.1 please follow previous upgrade guides and perform those upgrades incrementally**, eg.

1. [upgrade 3.7 to 4.0](three-dot-seven-to-four-dot-oh.md)
2. [upgrade 4.0 to 4.1](four-dot-oh-to-four-dot-one.md)
3. [upgrade 4.1 to 4.2](four-dot-one-to-four-dot-two.md)

This is the safest and recommended method.

## Update Gemfile

```ruby
gem 'spree', '>= 4.3'
```

## Remove gems merged into Spree Core

### \(Optional\) Remove SpreeMultiDomain

If you used that gem in the past you need to remove it. Multi-Store is now incorporated into Spree core and you cannot use that gem anymore.

1. Remove `spree_multi_domain` from your `Gemfile`
2. Remove `//= require spree/frontend/spree_multi_domain` from `vendor/assets/javascripts/spree/frontend/all.js`
3. Remove `//= require spree/backend/spree_multi_domain` from `vendor/assets/javascripts/spree/backend/all.js`

### \(Optional\) Remove Spree Editor

Spree 4.3 includes TinyMCE 5 editor built-in. It's not recommended to use `spree_editor` gem anymore.

### \(Optional\) Remove Spree Static Content

Spree 4.3 includes a built-in CMS. It's not recommended to use `spree_static_content`

## Add Spree modules

Spree 4.3 was split into separate modules which aren't included in the `spree` package anymore.

### \(Optional\) Add `spree_frontend` gem

If you use the default Spree Storefront you need to add it to your `Gemfile`. 

Note: If you are using `spree_auth_devise`, make sure `spree_frontend` precedes it in your Gemfile.

```ruby
gem 'spree_frontend', '>= 4.3'
```

### \(Optional\) Add `spree_backend` gem

If you use the default Spree Admin Panel you need to add it to your `Gemfile`. Make sure it comes before `spree_auth_devise`.

Note: If you are using `spree_auth_devise`, make sure `spree_backend` precedes it in your Gemfile.


```ruby
gem 'spree_backend', '>= 4.3'
```

### \(Optional\) Add `spree_emails` gem

Transactional emails once part of `spree_core` were extracted into their own gem called `spree_emails`. If you would like to still use this feature you'll need to include this new gem in your `Gemfile`.

```ruby
gem 'spree_emails', '>= 4.3'
```

## Update gems

```bash
bundle update
```

## Install missing migrations

```bash
bin/rails spree:install:migrations
```

## Run migrations

```bash
bin/rails db:migrate
```

## Additional fixes and hints

### Upgrade Sprockets to v4

In your project create  `app/assets/config/manifest.jss` file with contents: 

```ruby
//= link_tree ../images
//= link_tree ../javascripts
//= link_directory ../stylesheets .css
```

More [on this topic](https://github.com/rails/sprockets/blob/master/UPGRADING.md#manifestjs).

### Update Spree Auth Devise and Spree Gateway

```bash
bundle update spree_gateway spree_auth_devise
```

### Admin Panel fix

If you've developed custom features for your Admin Panel, please replace

```ruby
render partial: 'spree/shared/error_messages'
```

with

```ruby
render partial: 'spree/admin/shared/error_messages'
```

## Upgrade all of your Spree extensions to the newest versions

To avoid errors and compatibility issues, please update all of your Spree extension gems to the newest versions which usually include fixes for the new Spree release, eg.

```bash
bundle update spree_related_products
```

## Read the release notes

For information about changes contained within this release, please read the [CHANGELOG](https://github.com/spree/spree/blob/master/CHANGELOG.md).

## More info

If you have any questions or suggestions feel free to [contact us via email](https://spreecommerce.org/contact) or through [Spree slack channels](http://slack.spreecommerce.org/)

