---
title: Upgrading Spree from 3.1.x to 3.2.x
section: upgrades
order: 5
---

This guide covers upgrading a 3.1.x Spree store, to a 3.2.x store.

### Update your Rails version to 5.0

Please follow the
[official Rails guide](http://edgeguides.rubyonrails.org/upgrading_ruby_on_rails.html#upgrading-from-rails-4-2-to-rails-5-0)
to upgrade your store.

### Update Gemfile

```ruby
gem 'spree', '~> 3.2.0'
gem 'spree_auth_devise', '~> 3.2.0'
gem 'spree_gateway', '~> 3.2.0'
```

### Update your extensions

We're changing how extensions dependencies work. Previously you had to match
extension branch to Spree branch. Starting from now `master` branch of all
`spree-contrib` extensions should work with Spree >= `3.1` and < `4.0`. Please change
your extensions in Gemfile eg.:

from:

```ruby
gem 'spree_braintree_vzero', github: 'spree-contrib/spree_braintree_vzero', branch: '3-1-stable'
```

to:

```ruby
gem 'spree_braintree_vzero', github: 'spree-contrib/spree_braintree_vzero'
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

## Read the release notes

For information about changes contained within this release, please read the [3.2.0 Release Notes](http://guides.spreecommerce.org/release_notes/spree_3_2_0.html).

## Verify that everything is OK

Run you test suite, click around in your store and make sure it's performing as normal. Fix any deprecation warnings you see.
