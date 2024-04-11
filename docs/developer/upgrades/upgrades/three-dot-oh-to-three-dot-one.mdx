---
title: Upgrading Spree from 3.0 to 3.1
section: upgrades
order: 9
description: 'This guide covers upgrading a 3.0.x Spree store, to a 3.1.x store'
---

# 3.0 to 3.1

## Upgrade Rails

For this Spree release, you will need to upgrade your Rails version to at least 4.2.6.

```ruby
gem 'rails', '~> 4.2.6'
```

## Upgrade Spree

For best results, use the spree gem in version 3.1.x:

```ruby
gem 'spree', '~> 3.1.0.rc1'
```

Run `bundle update spree`.

## Copy and run migrations

Copy over the migrations from Spree \(and any other engine\) and run them using these commands:

```text
rake railties:install:migrations
rake db:migrate
```

## Spree Auth Devise & Spree Gateway

If you are using Spree Gateway and/or Spree Auth Devise you should also upgrade them:

```ruby
gem 'spree_auth_devise', '~> 3.1.0.rc1'
gem 'spree_gateway', '~> 3.1.0.rc1'
```

For Spree Auth Devise run installer:

```text
rails g spree:auth:install
```

\(you don't have to override config/initializers/devise.rb\)

## Additional information

### Make sure to v1 namespace custom rabl templates & overrides.

If your rabl templates reference others with extend you'll need to add the v1 namespace.

For example:

```ruby
extends 'spree/api/zones/show'
```

Becomes:

```ruby
extends 'spree/api/v1/zones/show'
```

### Remove Spree::Config.check\_for\_spree\_alerts

If you were disabling the alert checks you'll now want to remove this preference as it's no longer used.

## Read the release notes

For information about changes contained within this release, please read the [3.1.0 Release Notes](http://guides.spreecommerce.org/release_notes/spree_3_1_0.html).

## Verify that everything is OK

Run your test suite, click around in your store and make sure it's performing as normal. Fix any deprecation warnings you see.

