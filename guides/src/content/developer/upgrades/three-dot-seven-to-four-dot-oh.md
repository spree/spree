---
title: Upgrading Spree 3.7 to 4.0
section: upgrades
order: 0
---

This guide covers upgrading a **3.7 Spree application** to **Spree 4.0**. 

If you have any questions or suggestions feel free to reach out through [Spree slack channels](http://slack.spreecommerce.org/)

**If you're on an older version than 3.7 please follow previous upgrade guides and perform those upgrades incrementally**, eg.

1. [upgrade 3.2 to 3.3](/developer/upgrades/three-dot-two-to-three-dot-three.html)
2. [upgrade 3.3 to 3.4](/developer/upgrades/three-dot-three-to-three-dot-four.html)
3. [upgrade 3.4 to 3.5](/developer/upgrades/three-dot-four-to-three-dot-five.html)
4. [upgrade 3.5 to 3.6](/developer/upgrades/three-dot-five-to-three-dot-six.html)
5. [upgrade 3.6 to 3.7](/developer/upgrades/three-dot-six-to-three-dot-seven.html)

This is the safest and recommended method.

## Update your Ruby version to 2.5.0 at least

Spree 4.0 and Rails 6.0 require Ruby 2.5.0 at least so you need to bump the ruby version in your project's `Gemfile` and `.ruby-version` files.

## Update your Rails version to 6.0

Please follow the
[official Rails guide](https://edgeguides.rubyonrails.org/upgrading_ruby_on_rails.html#upgrading-from-rails-5-2-to-rails-6-0)
to upgrade your store.

## Migrate from Paperclip to ActiveStorage

In Spree 3.6 we deprecated [Paperclip support in favour of ActiveStorage](/release_notes/3_6_0.html#active-storage-support). Paperclip gem itself isn't maintained anymore and it is recommended to move to ActiveStorage as it is the defualt Rails storage engine since Rails 5.2 release.

In Spree 4.0 we completely removed Paperclip support in favour of ActiveStorage.

Also please remove any occurances of `Rails.application.config.use_paperclip` and `Configuration::Paperclip` in your codebase.

Please follow the [official Paperclip to ActiveStorage migration guide](https://github.com/thoughtbot/paperclip/blob/master/MIGRATING.md)

## Replace `class_eval` with `Module.prepend`

Rails 6.0 ships with [new code autoloader called Zeitwerk](https://medium.com/@fxn/zeitwerk-a-new-code-loader-for-ruby-ae7895977e73) which has some [strict rules in terms of file naming and contents](https://github.com/fxn/zeitwerk#file-structure). If you used `class_eval` to extend and modify Spree classes you will need to rewrite those with `Module.prepend`. Eg.

Old decorator - `app/models/spree/order_decorator.rb`

```ruby
Spree::Order.class_eval do
  has_many :new_custom_model

  def some_method
     # ...
  end
end
```

New decorator - `app/models/my_store/spree/order_decorator.rb`

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

Please also consider other options for [Logic Customization](/developer/customization/logic.html).

We recommend also reading through [Ruby modules: Include vs Prepend vs Extend](https://medium.com/@leo_hetsch/ruby-modules-include-vs-prepend-vs-extend-f09837a5b073)

## Replace OrderContents with services in your codebase

`OrderContents` was deprecated in Spree 3.7 and removed in 4.0. We've replaced it with [service objects](/release_notes/3_7_0.html#service-oriented-architecture).

You need to replace any instances of `OrderContents` usage with coresponding services in your codebase.

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

If you're using [Address Book](https://github.com/spree-contrib/spree_address_book) extension you need to remove as this feature was [merged into core Spree](/release_notes/4_0_0.html#address-book-support).

### Remove it from Gemfile

Remove this line:

```ruby
gem 'spree_address_book', github: 'spree-contrib/spree_address_book'
```

### Remove it from `vendor/assets/javascripts/spree/frontend/all.js`

Remove this line if your're using `spree_frontend`:

```
//= require spree/frontend/spree_address_book
```

### Remove it from `vendor/assets/stylesheets/spree/frontend/all.css`

Remove this line if your're using `spree_frontend`:

```
//= require spree/frontend/spree_address_book
```

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
