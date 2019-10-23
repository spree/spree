---
title: Upgrading Spree from 2.1.x to 2.2.x
section: upgrades
order: 9
---

## Overview

This guide covers upgrading a 2.1.x Spree store, to a 2.2.x store. This
guide has been written from the perspective of a blank Spree 2.1.x store with
no extensions.

If you have extensions that your store depends on, you will need to manually
verify that each of those extensions work within your 2.2.x store once this
upgrade is complete. Typically, extensions that are compatible with this
version of Spree will have a 2-2-stable branch.

## Upgrade Rails

For this Spree release, you will need to upgrade your Rails version to at least 4.0.6.

```ruby
gem 'rails', '~> 4.0.6'
```

## Upgrade Spree

For best results, use the 2-2-stable branch from GitHub:

````ruby
gem 'spree', github: 'spree/spree', branch: '2-2-stable'```

Run `bundle update spree`.

## Copy and run migrations

Copy over the migrations from Spree (and any other engine) and run them using
these commands:

    rake railties:install:migrations
    rake db:migrate

## Read the release notes

For information about changes contained with this release, please read the [2.2.0 Release Notes](http://guides.spreecommerce.org/release_notes/spree_2_2_0.html).

### Rename assets

As mentioned in the release notes, asset paths have changed. Change the references on the left, to the ones on the right:

* `admin/spree_backend` => `spree/backend`
* `store/spree_frontend` => `spree/frontend`

This applies across the board on Spree, and may need to be done in your store's extensions.

### Paperclip settings have been removed from master

Please consult [this section](http://guides.spreecommerce.org/release_notes/spree_2_2_0.html#paperclip-settings-have-been-removed) of the release notes if you were using custom Paperclip settings. This will direct you what to do in that particular case.

## Verify that everything is OK

Click around in your store and make sure it's performing as normal. Fix any deprecation warnings you see.
````
