---
title: Creating an Endpoint with Custom Attributes
---

## Introduction

One of the greatest things about both Spree is its flexibility. Using this full-featured open source e-commerce package means that you are total freedom to customize it to suit your business' own special needs.

The Spree Integrator extends the customizations you make in your store's schema so that you can make use of them within your third party service.

In this tutorial, you will:

* create a Spree sandbox store,
* add custom attributes to it,
* extend the store's JSON output to include the new attributes,
* create a custom endpoint for a fictional third-party service, and
* use this endpoint to access and utilize your store's custom attributes.

## Prerequisites

This tutorial assumes that you have installed [bundler](http://bundler.io/#getting-started) and [Sinatra](http://www.sinatrarb.com/intro.html), and that you have a working knowledge of [Ruby](http://www.ruby-lang.org/en/), [JSON](http://www.json.org/), [Sinatra](http://www.sinatrarb.com/), and [Rack](http://rack.rubyforge.org). It also assumes that you are using Rails 4 and Ruby 2.0.

## Creating a Sandbox Store

First, clone the spree gem:

```bash
$ git clone https://github.com/spree/spree.git
```

Then go into this new `spree` directory and run the following command to generate the sandbox app:

```bash
$ bundle exec rake sandbox
```

This creates the sandbox Spree store, complete with sample data and a default admin user, with the username **spree@example.com** and password **spree123**.

## Adding Custom Attributes to Store

Suppose that the nature of your business is such that you often sell products to businesses rather than solely to individuals. Suppose further than the fulfillment company you use handles shipments to businesses differently than those to home addresses. This scenario requires that you add a new `variety` attribute to your Spree store's `Address` objects.

***
A `type` attribute would work nicely here, but since `type` is a reserved word in ActiveRecord, and we want our store's frontend to continue to function flawlessly, we have to go with a different term. The customer will never know the difference, since we can still use "Address Type" as our input's label.
***

Let's generate a migration to add the new field.

```bash
$ bundle exec rails g migration add_variety_field_to_addresses
```

--- add_variety_field_to_addresses.rb ---
```ruby
change
  add_column :spree_addresses, :variety, :string
end
```

Run the migration. 

```bash
$ bundle exec rake db:migrate
```

Next, we need to make the field attr_accessible on the `Address` object. Create a new file: `/app/models/spree/address_decorator.rb` and add the following content to it:

```ruby
module Spree
  Address.class_eval do
    attr_accessible :variety
  end
end
```

Next, we need to add this field to the checkout form so customers can indicate the type of address. The checkout form resides within the `spree` gem at `/frontend/app/views/spree/address/_form.html.erb`, the relevant portion of which is:

```erb
<%% address_id = address_type.chars.first %>
<div class="inner" data-hook=<%%="#{address_type}_inner" %>>
  <p class="field" id=<%%="#{address_id}firstname" %>>
    <%%= form.label :firstname, Spree.t(:first_name) %><span class="required">*</span><br />
    <%%= form.text_field :firstname, :class => 'required' %>
  </p>
  ...
  <!-- other address fields here -->
</div>
```

We're going to use the [deface gem](https://github.com/spree/deface) to make changes to the spree app files.

Create a new file at `/app/overrides/spree/address/_form/address_variety_override.html.erb.deface` and include the following content:

```erb
<!-- insert_top 'div.inner' -->
<p class="field" id=<%%="#{address_id}variety" %>>
  <%%= form.label :variety, Spree.t(:variety) %><br />
  <%%= form.select :variety, ["Residence", "Business", "Other"] %>
</p>```

Now, when you go to your store and check out, you should see the new select box at the address entry step.

![Variety Select Box](/images/integration/address_variety_select.jpg)

Given that we will be selling to business addresses, we should enable the site-wide setting to show the "Company" field in the address section of checkout. Open the `/config/initializers/spree.rb` file. Update the `config` block as follows:

```ruby
Spree.config do |config|
  config.company = true
end```

Save your changes, then stop and restart your server to load the new configuration information. Now, when you go to checkout, you will see the new "Company" field.

![Company Field at Checkout](/images/integration/company_field_checkout.jpg)

## Extending JSON Output

## Creating Custom Endpoint

## Accessing Custom Data