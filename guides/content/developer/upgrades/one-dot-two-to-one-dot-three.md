---
title: Upgrading Spree from 1.2.x to 1.3.x
section: upgrades
---

## Overview

This guide covers upgrading a 1.2.x Spree store, to a 1.3.x store. This
guide has been written from the perspective of a blank Spree 1.2.x store with
no extensions.

If you have extensions that your store depends on, you will need to manually
verify that each of those extensions work within your 1.3.x store once this
upgrade is complete. Typically, extensions that are compatible with this
version of Spree will have a 1-3-stable branch.

## Upgrade Spree

For best results, use the 1-3-stable branch from GitHub:

```ruby
gem 'spree', :github => 'spree/spree', :branch => '1-3-stable'```

Run `bundle update spree`. 

## Bump jquery-rails

This version of Spree bumps the dependency for jquery-rails to this:

```ruby
gem 'jquery-rails', '2.2.0'```

Ensure that you have a line such as this in your Gemfile to allow that dependency.

## Copy and run migrations

Copy over the migrations from Spree (and any other engine) and run them using
these commands:

    rake railties:install:migrations
    rake db:migrate

## Replace money usages

In older versions of Spree, we had a helper method called `money` which
occasionally formatted money amounts incorrectly. Specifically, if the `I18n.locale` was changed, currencies started to display in that amount, rather than the proper amount. An item that was once $100, would suddenly become 100¥ if the locale was switched to Japanese, for instance.

In Spree 1.3, money handling
has been reworked by a major contribution by the [Free Running
Technologies](http://www.freerunningtech.com/) team. See [#2197](https://github.com/spree/spree/pull/2197) for details.

Prices are now stored in a separate table, called `spree_prices`. This table tracks the variant, the price amount, and the currency. This allows for variants to have different prices in different currencies.

Along with this, we introduced the `Spree::Money` class which is used to display amounts correctly. Where previously Spree would have done this:

```erb
<td><%%= money adjustment.amount %></td>```

We now use this:

```erb
<td><%%= adjustment.display_amount.to_html %></td>```

Alternatively, you can use `Spree::Money.new(amount)` to get a `Spree::Money` representation. Calling `to_html` on that object will format it neatly for HTML views, and calling `to_s` will format it nicely everywhere else.

### Variant.active scope

Along with these changes, the `Spree::Variant.active` scope now takes an argument for the currency. Whatever currency is specified will return variants in that currency. Previously it may have been enough to just do this:

```ruby
@product.variants.active```

But now you must specify a currency:

```ruby
@product.variants.active("USD")```

Or you can rely on the current currency within views:

```ruby
@product.variants.active(current_currency)```

## Read the release notes

For information about changes contained with this release, please read the [1.3.0 Release Notes](http://guides.spreecommerce.com/release_notes/spree_1_3_0.html).

## Verify that everything is OK

Click around in your store and make sure it's performing as normal. Fix any deprecation warnings you see.
