---
title: Deface Overrides
section: tutorial
hidden: true
---

<alert kind="warning">
  Using Deface is not recommended. Please refer to [View Customization section](/developer/customization/view.html) for more information.
</alert>

## Introduction

This tutorial is a continuation of the previous one, [Extensions](/developer/tutorials/extensions_tutorial.html), and begins where we left off in the last one. We have created a simple extension for promoting on-sale products on a "sales homepage".

In this tutorial we are going to learn about [Deface](https://github.com/spree/deface) and how we can use it to improve our extension. As part of improving our extension, we will be updating the existing Spree admin interface so that we are able to set the `sale_price` for products.

## What is Deface?

Deface is a standalone Rails library that enables you to customize Erb templates
without needing to directly edit the underlying view file. Deface allows you to
use standard CSS3 style selectors to target any element (including Ruby blocks),
and perform an action against all the matching elements.

## Improving Our Extension Using Deface

### The Goal

Our goal is to add a field to the product edit admin page that allows the `sale_price` to be added or updated. We could do this by overriding the view Spree provides, but there are potential problems with this technique. If Spree updates the view in a new release we won't get the updated view as we are already overriding it. We would need to update our view with the new content from Spree and then add our customizations back in to stay fully up to date.

Let's do this instead using Deface, which we just learned about. Using Deface will allow us to keep our view customizations in one spot, `app/overrides`, and make sure we are always using the latest implementation of the view provided by Spree.

### The Implementation

We want to override the product edit admin page, so the view we want to modify in this case is the product form partial. This file's path will be `spree/admin/products/_form.html.erb`.

First, let's create the overrides directory with the following command:

```bash
mkdir app/overrides
```

So we want to override `spree/admin/products/_form.html.erb`. Here is the part of the file we are going to add content to (you can also view the [full file](https://github.com/spree/spree/blob/master/backend/app/views/spree/admin/products/_form.html.erb)):

```erb
<div class="right four columns omega" data-hook="admin_product_form_right">
  <%= f.field_container :price do %>
    <%= f.label :price, raw(Spree.t(:master_price) + required_span_tag) %>
    <%= f.text_field :price, value: number_to_currency(@product.price, unit: '')%>
    <%= f.error_message_on :price %>
  <% end %>
</div>
```

We want our override to insert another field container after the price field container. We can do this by creating a new file `app/overrides/add_sale_price_to_product_edit.rb` and adding the following content:

```ruby
Deface::Override.new(virtual_path: 'spree/admin/products/_form',
  name: 'add_sale_price_to_product_edit',
  insert_after: "erb[loud]:contains('text_field :price')",
  text: "
    <%%= f.field_container :sale_price do %>
      <%%= f.label :sale_price, raw(Spree.t(:sale_price) + content_tag(:span, ' *')) %>
      <%%= f.text_field :sale_price, value:
        number_to_currency(@product.sale_price, unit: '') %>
      <%%= f.error_message_on :sale_price %>
    <%% end %>
  ")
```

We also need to delegate `sale_price` to the master variant in order to get the
updated product edit form working.

We can do this by creating a new file `app/models/spree/product_decorator.rb` and adding the following content to it:

```ruby
module Spree
  Product.class_eval do
    delegate :sale_price, :sale_price=, to: :master
  end
end
```

Now, when we head to `http://localhost:3000/admin/products` and edit a product, we should be able to set a sale price for the product and be able to view it on our sale page, `http://localhost:3000/sale`. Note that you will likely need to restart our example Spree application (created in the [Getting Started](/developer/tutorials/getting_started_tutorial.html) tutorial).

### Available actions

Deface applies an **action** to element(s) matching the supplied CSS selector. These actions are passed when defining a new override are supplied as the key while the CSS selector for the target element(s) is the value, for example:

```ruby
remove: "p.junk"

insert_after: "div#wow p.header"

insert_bottom: "ul#giant-list"
```

Deface currently supports the following actions:

- <tt>:remove</tt> - Removes all elements that match the supplied selector
- <tt>:replace</tt> - Replaces all elements that match the supplied selector, with the content supplied
- <tt>:replace_contents</tt> - Replaces the contents of all elements that match the supplied selector
- <tt>:surround</tt> - Surrounds all elements that match the supplied selector, expects replacement markup to contain <%%= render_original %> placeholder
- <tt>:surround_contents</tt> - Surrounds the contents of all elements that match the supplied selector, expects replacement markup to contain <%%= render_original %> placeholder
- <tt>:insert_after</tt> - Inserts after all elements that match the supplied selector
- <tt>:insert_before</tt> - Inserts before all elements that match the supplied selector
- <tt>:insert_top</tt> - Inserts inside all elements that match the supplied selector, as the first child
- <tt>:insert_bottom</tt> - Inserts inside all elements that match the supplied selector, as the last child
- <tt>:set_attributes</tt> - Sets attributes on all elements that match the supplied selector, replacing existing attribute value if present or adding if not. Expects :attributes option to be passed.
- <tt>:add_to_attributes</tt> - Appends value to attributes on all elements that match the supplied selector, adds attribute if not present. Expects :attributes option to be passed.
- <tt>:remove_from_attributes</tt> - Removes value from attributes on all elements that match the supplied selector. Expects :attributes option to be passed.

---

Not all actions are applicable to all elements. For example, <tt>:insert_top</tt> and <tt>:insert_bottom</tt> expects a parent element with children.

---

### Supplying content

Deface supports three options for supplying content to be used by an override:

- <tt>:text</tt> - String containing markup
- <tt>:partial</tt> - Relative path to a partial
- <tt>:template</tt> - Relative path to a template

---

As Deface operates on the Erb source the content supplied to an override can include Erb, it is not limited to just HTML. You also have access to all variables accessible in the original Erb context.

---

### Targeting elements

While Deface allows you to use a large subset of CSS3 style selectors (as provided by Nokogiri), the majority of Spree's views have been updated to include a custom HTML attribute (<tt>data-hook</tt>), which is designed to provide consistent targets for your overrides to use.

As Spree views are changed over coming versions, the original HTML elements maybe edited or be removed. We will endeavour to ensure that data-hook / id combination will remain consistent within any single view file (where possible), thus making your overrides more robust and upgrade proof.

For example, spree/products/show.html.erb looks as follows:

```erb
<div data-hook="product_show" itemscope itemtype="http://schema.org/Product">
  <%% body_id = 'product-details' %>
  <div class="columns six alpha" data-hook="product_left_part">
    <div class="row" data-hook="product_left_part_wrap">
      <div id="product-images" data-hook="product_images">
        <div id="main-image" data-hook>
          <%%= render 'image' %>
        </div>

        <div id="thumbnails" data-hook>
          <%%= render 'thumbnails', product: product %>
        </div>
      </div>

      <div data-hook="product_properties">
        <%%= render 'properties' %>
      </div>

    </div>
  </div>

  <div class="columns ten omega" data-hook="product_right_part">
    <div class="row" data-hook="product_right_part_wrap">

      <div id="product-description" data-hook="product_description">

        <h1 class="product-title" itemprop="name"><%%= accurate_title %></h1>

        <div itemprop="description" data-hook="description">
          <%%= product_description(product) rescue Spree.t(:product_has_no_description) %>
        </div>

        <div id="cart-form" data-hook="cart_form">
          <%%= render 'cart_form' %>
        </div>
      </div>

      <%%= render 'taxons' %>
    </div>
  </div>
</div>
```

As you can see from the example above the `data-hook` can be present in
a number of ways:

- On elements with **no** `id` attribute the `data-hook` attribute
  contains a value similar to what would be included in the `id`
  attribute.
- On elements with an `id` attribute the `data-hook` attribute does
  **not** normally contain a value.
- Occasionally on elements with an `id` attribute the `data-hook` will
  contain a value different from the elements id. This is generally to
  support migration from the old 0.60.x style of hooks, where the old
  hook names were converted into `data-hook` versions.

The suggested way to target an element is to use the `data-hook`
attribute wherever possible. Here are a few examples based on
**products/show.html.erb** above:

```ruby
replace: "[data-hook='product_show']"

insert_top: "#thumbnails[data-hook]"

remove: "[data-hook='cart_form']"
```

You can also use a combination of both styles of selectors in a single
override to ensure maximum protection against changes:

```ruby
 insert_top: "[data-hook='thumbnails'], #thumbnails[data-hook]"
```

### Targeting ruby blocks

Deface evaluates all the selectors passed against the original erb view
contents (and importantly not against the finished / generated HTML). In
order for Deface to make ruby blocks contained in a view parseable they
are converted into a pseudo markup as follows.

---

Version 1.0 of Deface, used in Spree 2.1, changed the code tag syntax.
Formerly code tags were parsed as `<code erb-loud>` and `<code erb-silent>`. They are now parsed as `<erb loud>` and `<erb silent>`.
Deface overrides which used selectors like `code[erb-loud]` should now
use `erb[loud]`.

---

Given the following Erb file:

```erb
<%% if products.empty? %>
 <%%= Spree.t(:no_products_found) %>
<%% elsif params.key?(:keywords) %>
  <h3><%%= Spree.t(:products) %></h3>
<%% end %>
```

Would be seen by Deface as:

```html
<!-- <html>
  <erb[silent]> if products.empty? </erb>
  <erb[loud]> Spree.t(:no_products_found) </erb>
  <erb[silent]> elsif params.key?(:keywords) </erb>

  <h3><erb[loud]> Spree.t(:products) </erb></h3>

  <erb[silent]> end </erb>
</html> -->
```

So you can target ruby code blocks with the same standard CSS3 style
selectors, for example:

```ruby
replace: "erb[loud]:contains('t(:products)')"

insert_before: "erb[silent]:contains('elsif')"
```

### View upgrade protection

To ensure upgrading between versions of Spree is as painless as
possible, Deface supports an `:original` option that can contain a
string of the original content that's being replaced. When Deface is
applying the override it will ensure that the current source matches the
value supplied and will output to the Rails application log if they are
different.

These warnings are a good indicator that you need to review the source
and ensure your replacement is adequately replacing all the
functionality provided by Spree. This will help reduce unexpected issues
after upgrades.

Once you've reviewed the new source you can update the `:original` value
to new source to clear the warning.

---

Deface removes all whitespace from both the actual and `:original`
source values before comparing, to reduce false warnings caused by basic
whitespace differences.

---

### Organizing Overrides

The suggested method for organizing your overrides is to create a
separate file for each override inside the **app/overrides** directory,
naming each file the same as the **:name** specified within.

---

Using this method will ensure your overrides are compatible with
future theming developments (editor).

---

### More information on Deface

For more information and sample overrides please refer to its
[README](https://github.com/spree/deface) file on GitHub.
