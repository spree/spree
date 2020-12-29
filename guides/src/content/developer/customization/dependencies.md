---
title: Dependency system
section: customization
order: 3
---

## Overview

Dependency is a a new way to customize Spree. With Dependencies you can easily replace parts of Spree internals with your custom classes. You can replace [Services](https://github.com/spree/spree/tree/master/core/app/services/spree), Abilities and [Serializers](https://github.com/spree/spree/tree/master/api/app/serializers/spree/v2). More will come in the future.

<alert kind="warning">
  Dependencies are available in [Spree 3.7](/release_notes/3_7_0.html) and later.
</alert>

## Controller level customization

To replace [serializers](https://github.com/Netflix/fast_jsonapi) or Services in a specific API endpoint you can create a simple decorator:

Create a `app/controllers/my_store/spree/cart_controller_decorator.rb`

```ruby
  module MyStore
    module Spree
      module CartControllerDecorator
        def resource_serializer
          MyNewAwesomeCartSerializer
        end

        def add_item_service
          MyNewAwesomeAddItemToCart
        end
      end
    end
  end
  Spree::Api::V2::Storefront::CartController.prepend MyStore::Spree::CartControllerDecorator
```

This will change the serializer in this API endpoint to `MyNewAwesomeCartSerializer` and also it will swap the default `add_item_service` to `MyNewAwesomeAddItemToCart`.

Different API endpoints can have different dependency injection points. You can review their [source code](https://github.com/spree/spree/tree/master/api/app/controllers/spree/api/v2) to see what you can configure.

## API level customization

Storefront and Platform APIs have separate Dependencies injection points so you can easily customize one without touching the other.

In your Spree initializer (`config/initializers/spree.rb`) please add:

```ruby
Spree::Api::Dependencies.storefront_cart_serializer = 'MyNewAwesomeCartSerializer'
Spree::Api::Dependencies.storefront_cart_add_item_service = 'MyNewAwesomeAddItemToCart'
```

This will swap the default Cart serializer and Add Item to Cart service for your custom ones within all Storefront API endpoints that uses those classes.

<alert kind="warning">
  Values set in the initializer has to be strings, eg. `'MyNewAwesomeAddItemToCart'`
</alert>

## Application (global) customization

You can also inject classes globally to the entire Spree stack. Be careful about this though as this touches every aspect of the application (both APIs, Admin Panel and default Rails frontend if you're using it).

```ruby
Spree::Dependencies.cart_add_item_service = 'MyNewAwesomeAddItemToCart'
```

or

```ruby
Spree.dependencies do |dependencies|
  dependencies.cart_add_item_service = 'MyNewAwesomeAddItemToCart'
end
```

You can mix and match both global and API level customizations:

```ruby
Spree::Dependencies.cart_add_item_service = 'MyNewAwesomeAddItemToCart'
Spree::Api::Dependencies.storefront_cart_add_item_service = 'AnotherAddItemToCart'
```

The second line will have precedence over the first one, and the Storefront API will use `AnotherAddItemToCart` and the rest of the application will use `MyNewAwesomeAddItemToCart`

<alert kind="warning">
  Values set in the initializer has to be strings, eg. `'MyNewAwesomeAddItemToCart'`
</alert>

## Default values

Default values can be easily checked looking at the source code of Dependencies classes:

- [Application (global) dependencies](https://github.com/spree/spree/blob/master/core/app/models/spree/app_dependencies.rb)
- [API level dependencies](https://github.com/spree/spree/blob/master/api/app/models/spree/api_dependencies.rb)
