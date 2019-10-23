---
title: Upgrading Spree from 3.5.x to 3.6.x
section: upgrades
order: 1
---

This guide covers upgrading a 3.5 Spree application, to a 3.6 application.

### Update Gemfile

```ruby
gem 'spree', '~> 3.6.1'
gem 'spree_auth_devise', '~> 3.3'
gem 'spree_gateway', '~> 3.3'
```

### Update your Rails version to 5.2

Please follow the
[official Rails guide](http://guides.rubyonrails.org/5_2_release_notes.html#upgrading-to-rails-5-2)
to upgrade your store.

### Run `bundle update`

### Migrate to ActiveStorage (optional)

Please follow the [official paperclip guide](https://github.com/thoughtbot/paperclip/blob/master/MIGRATING.md) if you
want to use ActiveStorage instead of paperclip.

You cann still use paperclip for attachment management by setting `SPREE_USE_PAPERCLIP` environment variable to `true`, but keep in mind that paperclip is DEPRECATED and we will remove paperclip support in Spree 4.0.

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

You're good to go!

## Read the release notes

For information about changes contained within this release, please read the [3.6.0 Release Notes](http://guides.spreecommerce.org/release_notes/spree_3_6_0.html).

## Verify that everything is OK

Run you test suite, click around in your application and make sure it's performing as normal. Fix any deprecation warnings you see.
