---
title: 'Extend Product Attributes'
section: tutorial
order: 0
---

## Overview

If you need to add more attributes to your product model you can easily extend spree. In this example you are going to extend your product with an `short_descripton` and make it manageable through admin.

Note: Replace `RailsappName` and `railsapp_name` with your actualy Rails App Name (sic!)

## Extend your Product
### Extend Product Attributes

Create a migration that extends your spree products table. `rails g migration AddFieldsToSpreeProducts short_description:text` should create this migration

```ruby
class AddFieldsToSpreeProducts < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_products, :short_description, :text
  end
end
```

This file extends your actual Product Serializer to make the attributes available in your *APP*.

```ruby
module RailsappName
  module Spree
    module ProductDecorator
      def self.prepended(base)
        base.attributes :short_description
      end
    end
  end
end

::Spree::V2::Storefront::Product.prepend RailsappName::Spree::ProductDecorator if ::Spree::V2::Storefront::Product.included_modules.exclude?(RailsappName::Spree::ProductDecorator)
```

File Location: `app/models/railsapp_name/spree/product_serializer_decorator.rb` (Does not exist by default)

### Make it available in your API

This file extends your actual Product Serializer to make the attributes available in your *API*.

```ruby
module RailsappName
  module Spree
    module ProductSerializerDecorator
      def self.prepended(base)
        base.attributes :short_description
      end
    end
  end
end

::Spree::V2::Storefront::ProductSerializer.prepend RailsappName::Spree::ProductSerializerDecorator if ::Spree::V2::Storefront::ProductSerializer.included_modules.exclude?(RailsappName::Spree::ProductSerializerDecorator)
```

File Location: `app/serializers/railsapp_name/spree/product_serializer_decorator.rb` (Does not exist by default)

### Add Fields to your admin interface

*Create Template for Admin Form*
```ruby
<div data-hook="admin_product_form_short_description">
  <%= f.field_container :short_description, class: ['form-group'] do %>
    <%= f.label :short_description %>
    <%= f.error_message_on :short_description %>
    <%= f.text_area :short_description, class: 'form-control', placeholder: 'Am besten drei Bullet Points' %>
  <% end %>
</div>
```

File Location: `app/views/spree/admin/products/_product_custom_fields.html` (Does not exist by default)

*Inject your Template to Admin Panel*

```ruby
Deface::Override.new(:virtual_path => "spree/admin/products/_form",
  :name => "product_custom_fields_admin_product_form_right",
  :insert_after => "[data-hook='admin_product_form_description']",
  :partial => "spree/admin/products/product_custom_fields",
  :original => "eb9ecf7015fa51bb0adf7dafd7e6fdf1d652025d",
  :disabled => false)
```

File Location: `app/overrides/add_custom_fields_product_admin_tabs.rb` (Does not exist by default)

## Gotchas, Known Issues, and Further Considerations
This extends your product just with simple fields and makes them available on your master product. Please be advised for more complex extensions it might make sense to create new tabs in your admin panel or manage this through a relationship.
