---
title: Logic Customization
section: customization
order: 4
---

## Overview

It is highly recommended to use [Dependencies](/developer/customization/dependencies.html) and [Extensions](/developer/customization/extensions.html) first rather than to apply patches to Spree Core. Still if you don't find those to be efficient you can pretty much overwrite any part of Spree following this guide.

## Extending Classes

All of Spree's business logic (models, controllers, helpers, etc) can
easily be extended or overridden to meet your exact requirements using
standard Ruby idioms.

Standard practice for including such changes in your application or
extension is to create a file within the relevant **app/models/spree** or
**app/controllers/spree** directory with the original class name with
**\_decorator** appended.

## Extending Models

Adding a custom method to the [Product](https://github.com/spree/spree/blob/master/core/app/models/spree/product.rb) model:
`app/models/my_store/spree/product_decorator.rb`

```ruby
module MyStore
  module Spree
    module ProductDecorator
      def some_method
        ...
      end
    end
  end
end

::Spree::Product.prepend MyStore::Spree::ProductDecorator if ::Spree::Product.included_modules.exclude?(MyStore::Spree::ProductDecorator)
```

## Extending Controllers

Adding a custom action to the [ProductsController](https://github.com/spree/spree/blob/master/frontend/app/controllers/spree/products_controller.rb):
`app/controllers/my_store/spree/products_controller_decorator.rb`

```ruby
module MyStore
  module Spree
    module ProductsControllerDecorator
      def some_action
        ...
      end
    end
  end
end

::Spree::ProductsController.prepend MyStore::Spree::ProductsControllerDecorator if ::Spree::ProductsController.included_modules.exclude?(MyStore::Spree::ProductsControllerDecorator)
```

The exact same format can be used to redefine an existing method.

### Accessing Product Data

If you extend the Products controller with a new method, you may very
well want to access product data in that method. You can do so by using
the `:load_data before_action`.

```ruby
module MyStore
  module Spree
    module ProductsControllerDecorator
      def self.prepended(base)
        base.before_action :load_data, only: :some_action
      end

      def some_action
        ...
      end
    end
  end
end

::Spree::ProductsController.prepend MyStore::Spree::ProductsControllerDecorator if ::Spree::ProductsController.included_modules.exclude?(MyStore::Spree::ProductsControllerDecorator)
```

`:load_data` will use `params[:id]` to lookup the product by its permalink.

## Replacing Models or Controllers

If your customizations are so large that you overwrite majority of a given Model or Controller we recommend to drop the `_decorator` pattern and overwrite the Model or Controller completely in your project. This will make future Spree upgrades easier.
