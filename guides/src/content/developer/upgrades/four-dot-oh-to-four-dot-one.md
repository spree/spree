---
title: Upgrading Spree 4.0 to 4.1
section: upgrades
order: 0
hidden: true
---

This guide covers upgrading a **4.0 Spree application** to **Spree 4.1**.

If you have any questions or suggestions feel free to reach out through [Spree slack channels](http://slack.spreecommerce.org/)

**If you're on an older version than 4.0 please follow previous upgrade guides and perform those upgrades incrementally**, eg.

1. [upgrade 3.3 to 3.4](/developer/upgrades/three-dot-three-to-three-dot-four.html)
2. [upgrade 3.4 to 3.5](/developer/upgrades/three-dot-four-to-three-dot-five.html)
3. [upgrade 3.5 to 3.6](/developer/upgrades/three-dot-five-to-three-dot-six.html)
4. [upgrade 3.6 to 3.7](/developer/upgrades/three-dot-six-to-three-dot-seven.html)
5. [upgrade 3.7 to 4.0](/developer/upgrades/three-dot-seven-to-four-dot-oh.html)

This is the safest and recommended method.

## Update Gemfile

```ruby
gem 'spree', '~> 4.1'
gem 'spree_auth_devise', '~> 4.1'
gem 'spree_gateway', '~> 3.6'
```

## Run `bundle update`

## Install missing migrations

```bash
rails spree:install:migrations
rails spree_api:install:migrations
rails spree_auth:install:migrations
rails spree_gateway:install:migrations
```

## Run migrations

```bash
rails db:migrate
```

## Read the release notes

For information about changes contained within this release, please read the [4.1.0 Release Notes](https://guides.spreecommerce.org/release_notes/spree_4_1_0.html).

## More info

If you have any questions or suggestions feel free to reach out through [Spree slack channels](http://slack.spreecommerce.org/)
