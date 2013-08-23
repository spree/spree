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

Suppose that the nature of your business is such that you often sell products to businesses rather than solely to individuals. Suppose further than the fulfillment company you use handles shipments to businesses differently than those to home addresses. This scenario requires that you add two new attributes to your Spree store's `Address` objects: `company_name` and `variety`.

***
A `type` attribute would work nicely here, but since `type` is a reserved word in ActiveRecord, and we want our store's frontend to continue to function flawlessly, we have to go with a different term. The customer will never know the difference, since we can still use "Address Type" as our input's label.
***

Let's generate a migration to add these two new fields.

```bash
$ bundle exec rails g migration add_company_fields_to_addresses
```

--- add_company_fields_to_addresses.rb ---
```ruby
change
  add_column :addresses, :company_name, :string
  add_column :addresses, :variety, :string
```
## Extending JSON Output

## Creating Custom Endpoint

## Accessing Custom Data