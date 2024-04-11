---
title: Upgrading Spree 3.7 to 4.0
section: upgrades
order: 2
description: This guide covers upgrading a 3.7 Spree application to Spree 4.0.
---

# 3.7 to 4.0

If you have any questions or suggestions feel free to reach out through [Spree slack channels](http://slack.spreecommerce.org/)

**If you're on an older version than 3.7 please follow previous upgrade guides and perform those upgrades incrementally**, eg.

1. [upgrade 3.2 to 3.3](https://dev-docs.spreecommerce.org/upgrades/upgrades/three-dot-two-to-three-dot-three)
2. [upgrade 3.3 to 3.4](https://dev-docs.spreecommerce.org/upgrades/upgrades/three-dot-three-to-three-dot-four)
3. [upgrade 3.4 to 3.5](https://dev-docs.spreecommerce.org/upgrades/upgrades/three-dot-four-to-three-dot-five)
4. [upgrade 3.5 to 3.6](https://dev-docs.spreecommerce.org/upgrades/upgrades/three-dot-five-to-three-dot-six)
5. [upgrade 3.6 to 3.7](https://dev-docs.spreecommerce.org/upgrades/upgrades/three-dot-six-to-three-dot-seven)

This is the safest and recommended method.

## Update your Ruby version to 2.5.0 at least

Spree 4.0 requires Ruby 2.5.0 at least so you need to bump the ruby version in your project's `Gemfile` and `.ruby-version` files.

## Migrate from Paperclip to ActiveStorage

In Spree 3.6 we deprecated [Paperclip support in favor of ActiveStorage](https://guides.spreecommerce.org/release_notes/3_6_0.html#active-storage-support). Paperclip gem itself isn't maintained anymore and it is recommended to move to ActiveStorage as it is the default Rails storage engine since Rails 5.2 release.

In Spree 4.0 we've removed Paperclip support in favor of ActiveStorage.

Please remove also any occurrences of `Rails.application.config.use_paperclip` and `Configuration::Paperclip` from your codebase.

Please follow the [official Paperclip to ActiveStorage migration guide](https://github.com/thoughtbot/paperclip/blob/master/MIGRATING.md).

## Replace OrderContents with services in your codebase

`OrderContents` was deprecated in Spree 3.7 and removed in 4.0. We've replaced it with [service objects](https://guides.spreecommerce.org/release_notes/3_7_0.html#service-oriented-architecture).

You need to replace any instances of `OrderContents` usage with corresponding services in your codebase.

### `OrderContents#update_cart`

before:

```ruby
order.contents.update_cart(line_items_attributes)
```

after:

```ruby
Spree::Cart::Update.call(order: order, params: line_items_attributes)
```

### `OrderContents#add`

before:

```ruby
order.contents.add(variant, quantity, shipment: shipment)
```

after:

```ruby
Spree::Cart::AddItem.call(
  order: order,
  variant: variant,
  quantity: quantity,
  options: {
    shipment: @shipment
  }
)
```

### `OrderContents#remove`

before:

```ruby
order.contents.remove(variant, quantity, shipment: shipment)
```

after:

```ruby
Spree::Cart::RemoveItem.call(
  order: order,
  variant: variant,
  quantity: quantity,
  options: {
    shipment: shipment
  }
)
```

## Replace `add_store_credit_payments` with `Checkout::AddStoreCredit`

Similar to `OrderContents` method `add_store_credit_payments` was replaced with `Checkout::AddStoreCredit` service.

before:

```ruby
order.add_store_credit_payments
```

after:

```ruby
Spree::Checkout::AddStoreCredit.call(order: order)
```

## Replace `remove_store_credit_payments` with `Checkout::RemoveStoreCredit`

Similar to `OrderContents` method `remove_store_credit_payments` was replaced with `Checkout::RemeoveStoreCredit` service.

before:

```ruby
order.remove_store_credit_payments
```

after:

```ruby
Spree::Checkout::RemoveStoreCredit.call(order: order)
```

## Remove `spree_address_book` extension

If you're using the [Address Book](https://github.com/spree-contrib/spree_address_book) extension you need to remove it as this feature was merged into [core Spree](https://guides.spreecommerce.org/release_notes/4_0_0.html#address-book-support).

1. Remove this line from `Gemfile`

   ```ruby
    gem 'spree_address_book', github: 'spree-contrib/spree_address_book'
   ```

2. Remove this line from `vendor/assets/javascripts/spree/frontend/all.js`

   ```text
    //= require spree/frontend/spree_address_book
   ```

3. Remove this line from `vendor/assets/stylesheets/spree/frontend/all.css`

   ```text
    //= require spree/frontend/spree_address_book
   ```

## Replace `class_eval` with `Module.prepend` \(only for Rails 6\)

Rails 6.0 ships with a [new code autoloader called Zeitwerk](https://medium.com/@fxn/zeitwerk-a-new-code-loader-for-ruby-ae7895977e73) which has some [strict rules in terms of file naming and contents](https://github.com/fxn/zeitwerk#file-structure). If you used `class_eval` to extend and modify Spree classes you will need to rewrite those with `Module.prepend`. Eg.

Old decorator syntax - `app/models/spree/order_decorator.rb`

```ruby
Spree::Order.class_eval do
  has_many :new_custom_model

  def some_method
     # ...
  end
end
```

New decorator syntax - `app/models/my_store/spree/order_decorator.rb`

```ruby
module MyStore
  module Spree
    module OrderDecorator
      def self.prepended(base)
        base.has_many :new_custom_model
      end

      def some_method
        # ...
      end
    end
  end
end

::Spree::Order.prepend(MyStore::Spree::OrderDecorator)
```

When migrating a class method to the new [autoloader](https://medium.com/@fxn/zeitwerk-a-new-code-loader-for-ruby-ae7895977e73) things are a little different because you will have to prepend to the Singleton class as shown in this example:

```ruby
module Spree::BaseDecorator
  def spree_base_scopes
    # custom implementation
  end
end

Spree::Base.singleton_class.send :prepend, Spree::BaseDecorator
```

Please also consider other options for [Logic Customization](../../customization/logic.md).

We recommend also reading through [Ruby modules: Include vs Prepend vs Extend](https://medium.com/@leo_hetsch/ruby-modules-include-vs-prepend-vs-extend-f09837a5b073)

## Update Bootstrap 3 to 4 or stay at Bootstrap 3

Spree 4 uses Bootstrap 4 for both Storefront and Admin Panel. You have two options:

### Stay at Bootstrap 3

As we know this is a big portion of work you can still use Bootstrap 3 for your Storefront.

1. Copy all remaining views by running `bundle exec spree:frontend:copy_views`
2. Add `bootstrap-sass` gem to your `Gemfile`

   ```ruby
    gem 'bootstrap-sass', '~> 3.4.1'
   ```

### Move to Bootstrap 4

[Follow the official Bootstrap 3 to 4 migration guide](https://getbootstrap.com/docs/4.0/migration/)

## Update Gemfile

```ruby
gem 'spree', '~> 4.0'
gem 'spree_auth_devise', '~> 4.0'
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

For information about changes contained within this release, please read the [4.0.0 Release Notes](https://guides.spreecommerce.org/release_notes/spree_4_0_0.html).

## More info

If you have any questions or suggestions feel free to reach out through [Spree slack channels](http://slack.spreecommerce.org/)

