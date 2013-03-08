---
title: Deface Overrides
---

## Introduction

This tutorial is a continuation of the previous one, [Extensions](/developer/tutorials/extensions/), and begins where we left off in the last one. We have created a simple extension for promoting on-sale products on a "sales homepage".

In this tutorial we are going to learn about [Deface](http://github.com/spree/deface) and how we can use it to improve our extension. As part of improving our extension, we will be updating the existing Spree admin interface so that we are able to set the `sale_price` for products.

## What is Deface?

Deface is a standalone Rails 3 library that enables you to customize Erb templates without needing to directly edit the underlying view file. Deface allows you to use standard CSS3 style selectors to target any element (including Ruby blocks), and perform an action against all the matching elements.

## Using Deface

As an example, let's look at what it would take to customize the Checkout Registration template in Spree. You don't actually have to follow along with these steps in our example application, this is just to show you the basics of using deface.

Here is what the erb template looks like in Spree:

```erb
<%%= render :partial => 'spree/shared/error_messages', :locals => { :target => @user } %>
<h2><%%= t(:registration) %></h2>
<div id="registration" data-hook>
  <div id="account" class="columns alpha eight">
    <!-- TODO: add partial with registration form -->
  </div>
  <%% if Spree::Config[:allow_guest_checkout] %>
    <div id="guest_checkout" data-hook class="columns omega eight">
      <%%= render :partial => 'spree/shared/error_messages', :locals => { :target => @order } %>
      <h2><%%= t(:guest_user_account) %></h2>
      <%%= form_for @order, :url => update_checkout_registration_path, :method => :put, :html => { :id => 'checkout_form_registration' } do |f| %>
        <p>
          <%%= f.label :email, t(:email) %><br />
          <%%= f.email_field :email, :class => 'title' %>
        </p>
        <p><%%= f.submit t(:continue), :class => 'button primary' %></p>
      <%% end %>
    </div>
  <%% end %>
</div>
```

If you wanted to insert some code just before the `#registration` div on the page, you would define an override in `app/overrides` (creating a new file with an `rb` extension) as follows:

```ruby
Deface::Override.new(:virtual_path  => "spree/checkout/registration",
                     :insert_before => "div#registration",
                     :text          => "<p>Registration is the future!</p>",
                     :name          => "registration_future")
```

This override will insert a paragraph tag with the content "Registration is the future!" before the `#registration` div.

Now let's go over some of the features Deface has to offer.

### Available Actions

Deface applies an action to element(s) matching the supplied CSS selector. These actions are passed when defining a new override are supplied as the key while the CSS selector for the target element(s) is the value, for example:

```ruby
:remove => "p.junk"

:insert_after => "div#wow p.header"

:insert_bottom => "ul#giant-list"
```

Deface currently supports the following actions:

* remove – Removes all elements that match the supplied selector
* replace – Replaces all elements that match the supplied selector, with the content supplied
* insert_after – Inserts content supplied after all elements that match the supplied selector
* insert_before – Inserts content supplied before all elements that match the supplied * selector
* insert_top – Inserts content supplied inside all elements that match the supplied selector, as the first child
* insert_bottom – Inserts content supplied inside all elements that match the supplied * selector, as the last child
* set_attributes – Sets (or adds) attributes to all elements that match the supplied selector, expects :attributes option to be passed

### Supplying Content

Deface supports three options for supplying content to be used by an override:

* text – String containing markup
* partial – Relative path to a partial
* template – Relative path to a template

### More Information on Using Deface

This just scratches the surface of what is possible using deface. For more detailed documentation, visit the [Deface Github repo](http://github.com/spree/deface).

## Improving Our Extension Using Deface

### The Goal

Our goal is to add a field to the product edit admin page that allows the `sale_price` to be or updated. We could do this by overriding the view Spree provides, but there are potential problems with this technique. If Spree updates the view in a new release we won't get the updated view as we are already overriding it. We would need to update our view with the new content from Spree and then add our customizations back in to stay fully up to date.

Let's do this instead using Deface, which we just learned about. Using Deface will allow us to keep our view customizations in one spot, `app/overrides`, and make sure we are always using the latest implementation the view provided by Spree.

### The Implementation

We want to override the product edit admin page, so the view we want to modify in this case is the product form partial. This file's path will be `spree/admin/product/_form`.

First, let's create the overrides directory with the following command:

```bash
$ mkdir app/overrides```

So we want to override `spree/admin/product/_form`. Here is the part of the file we are going to add content to (you can also view the [full file](https://github.com/spree/spree/blob/1-3-stable/core/app/views/spree/admin/products/_form.html.erb)):

```erb
<div class="right four columns omega" data-hook="admin_product_form_right">
<%%= f.field_container :price do %>
    <%%= f.label :price, raw(t(:master_price) + content_tag(:span, ' *', :class => "required")) %>
    <%%= f.text_field :price, :value => number_to_currency(@product.price, :unit => '') %>
    <%%= f.error_message_on :price %>
<%% end %>```

We want our override to insert another field container after the price field container. We can do this by creating a new file `app/overrides/add_sale_price_to_product_edit.rb` and adding the following content:

```ruby
Deface::Override.new(:virtual_path => "spree/admin/products/_form",
                     :name => "add_sale_price_to_product_edit",
                     :insert_after => "code[erb-loud]:contains('text_field :price')",
                     :text => "
                       <%%= f.field_container :sale_price do %>
                         <%%= f.label :sale_price, raw(t(:sale_price) + content_tag(:span, ' *')) %>
                         <%%= f.text_field :sale_price, :value => number_to_currency(@product.sale_price, :unit => '') %>
                         <%%= f.error_message_on :sale_price %>
                       <%% end %>
                     ")```

There is one more change we will need to make in order to get the updated product edit form working. We need to make `cost_price` attr_accessible on the `Spree::Product` model and delegate to the master variant for `cost_price`.

We can do this by creating a new file `app/models/spree/product_decorator.rb` and adding the following content to it:

```ruby
module Spree
  Product.class_eval do
  delegate_belongs_to :master, :sale_price

  attr_accessible :sale_price
  end
end```

Now, when we head to `http://localhost:3000/admin/products` and edit a product, we should be able to set a sale price for the product and be able to view it on our sale page, `http://localhost:3000/sale`. Note that you will likely need to restart our example Spree application (created in the [Getting Started](/developer/tutorial/getting_started/) tutorial).
