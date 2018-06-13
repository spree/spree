---
title: Upgrading Spree from 3.6.x to 3.7.x
section: upgrades
---

This guide covers upgrading a 3.6 Spree application, to a 3.7 application.

### Update Gemfile

```ruby
gem 'spree', '~> 3.7.0'
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

You're good to go!

## Additional information

`Order#guest_token` was renamed to `Order#token` in order to unify the experience for guest checkouts and orders placed by signed in users.

## Read the release notes

For information about changes contained within this release, please read the [3.7.0 Release Notes](http://guides.spreecommerce.org/release_notes/spree_3_7_0.html).

## Verify that everything is OK

Run you test suite, click around in your application and make sure it's performing as normal. Fix any deprecation warnings you see.
