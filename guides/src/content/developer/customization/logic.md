---
title: Logic Customization
section: customization
---

## Overview

This guide explains how to customize the internal Spree code to meet
your exact business requirements.

## Extending Classes

All of Spree's business logic (models, controllers, helpers, etc) can
easily be extended / overridden to meet your exact requirements using
standard Ruby idioms.

Standard practice for including such changes in your application or
extension is to create a file within the relevant **app/models/spree** or
**app/controllers/spree** directory with the original class name with
**_decorator** appended.

**Adding a custom method to the Product model:**
app/models/spree/product_decorator.rb

```ruby
Spree::Product.class_eval do
  def some_method
    ...
  end
end
```

**Adding a custom action to the ProductsController:**
app/controllers/spree/products_controller_decorator.rb

```ruby
Spree::ProductsController.class_eval do
  def some_action
    ...
  end
end
```

***
The exact same format can be used to redefine an existing method.
***

### Accessing Product Data

If you extend the Products controller with a new method, you may very
well want to access product data in that method. You can do so by using
the :load_data before_action.

```ruby
Spree::ProductsController.class_eval do
  before_action :load_data, only: :some_action

  def some_action
    ...
  end
end
```

***
:load_data will use params[:id] to lookup the product by its
permalink.
***
