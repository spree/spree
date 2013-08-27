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

***
To learn more about Spree's built-in preferences, see the [Preferences guide](/developer/preferences).
***

Save your changes, then stop and restart your server to load the new configuration information. Now, when you go to checkout, you will see the new "Company" field.

![Company Field at Checkout](/images/integration/company_field_checkout.jpg)

## Extending JSON Output

Once you [get connected to the Spree Integrator](configuration), it will periodically poll your store for any relevant new or updated information based on the [integrations](supported_integrations) you have enabled. This information is transmitted using a standardized [JSON format](terminology#messages) and includes all of the information from a basic Spree store, per the [Spree::Api::ApiHelpers class](https://github.com/spree/spree/blob/master/api/app/helpers/spree/api/api_helpers.rb). 

It will not include any customized attributes. To extend the JSON output to include your custom attributes, you need to decorate the `ApiHelpers` class within your project. Create a file at `/app/helpers/spree/api/api_helpers_decorator.rb` and update it as follows:

```ruby
Spree::Api::ApiHelpers.class_eval do
  def address_attributes_with_variety
    address_attributes_without_variety << :variety
  end

  alias_method_chain :address_attributes, :variety
end
```

Then, when your store's orders are output, you'll see the custom `variety` field in the JSON file (much of the output is omitted below for brevity).

```json
{
  "message": "order:new",
  "payload": {
    "order": {
      "id": 12345,
      "number": "R123456789",
      "line_items": [ ... ],
      "billing_address": {
        "firstname": "John",
        "lastname": "Smith",
        "address": "123 Main St.",
        "variety": "Residence"
      }
    }
  }
}
```

&&&
Figure out some way to get the JSON output to show that it really does what we just said it does.
&&&

## Creating Custom Endpoint

In the [Creating a Fulfillment Endpoint Tutorial](creating_fulfillment_tutorial), we made a basic endpoint that had some simple logic relating to shipments. In this tutorial, we'll create a similar fulfillment endpoint. In [the next section](#accessing-custom-data), we'll extend it to account for the custom attribute and take different actions accordingly.

First, we'll create a fake API with which to interact, called `DummyShip`.

---dummy_ship.rb---
```ruby
module DummyShip
  def self.validate_address(address)
    ## Zipcode must be within a given range.
    unless (20170..20179).to_a.include?(address['zipcode'].to_i)
      raise "This order is outside our shipping zone."
    end
  end
end```

Next, we need a new directory to house our integration files.

```bash
$ mkdir custom_attribute_endpoint
$ cd custom_attribute_endpoint```

Within our new `custom_attribute_endpoint` directory, we need:

---Gemfile---
```ruby
source 'https://rubygems.org'

gem 'endpoint_base', github: 'spree/endpoint_base'```

---config.ru---
```ruby
require './custom_attribute_endpoint'
require './dummy_ship'

run CustomAttributeEndpoint```

---custom_attribute_endpoint.rb---
```ruby
require 'endpoint_base'
require 'multi_json'

class CustomAttributeEndpoint < EndpointBase
  post '/validate_address' do
    address = @message[:payload]['order']['shipping_address']

    begin
      result = DummyShip.validate_address(address)
      process_result 200, { 'message_id' => @message[:message_id], 'message' => "notification:info",
        "payload" => { "result" => "The address is valid, and the shipment will be sent." } }
    rescue Exception => e
      process_result 200, { 'message_id' => @message[:message_id], 'message' => "notification:error",
        "payload" => { "result" => e.message } }
    end
  end
end```

The `validate_address` service will accept an incoming JSON file, compare the passed-in `shipping_address` to the `DummyShip` API's `validate_address` method, and return a `notification:info` message for a valid address, or a rescued exception for an invalid address.

To test this out, we need some JSON files - one with a valid address, and one with an invalid address.

---good_address.json---
```json
{
  "message": "order:new",
  "message_id": "518726r85010000001",
  "payload": {
    "order": {
      "shipping_address": {
        "firstname": "Chris",
        "lastname": "Mar",
        "address1": "112 Hula Lane",
        "address2": "",
        "city": "Leesburg",
        "zipcode": "20175",
        "phone": "555-555-1212",
        "company": "RubyLoco",
        "country": "US",
        "state": "Virginia"
      }
    }
  }
}```

---bad_address.json---
```json
{
  "message": "order:new",
  "message_id": "518726r85010000001",
  "payload": {
    "order": {
      "shipping_address": {
        "firstname": "Sally",
        "lastname": "Albright",
        "address1": "55 Rye Lane",
        "address2": "",
        "city": "Greensboro",
        "zipcode": "27235",
        "phone": "555-555-1212",
        "company": "Subs and Sandwiches",
        "country": "US",
        "state": "North Carolina"
      }
    }
  }
}```

Time to test it out in curl. First, the address that our API considers valid:

```bash
$ bundle exec rackup -p 9292
$ curl --data @./good_address.json -i -X POST -H 'Content-type:application/json' http://localhost:9292/validate_address

=> HTTP/1.1 200 OK
Content-Type: application/json;charset=utf-8
Content-Length: 141
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/1.9.3/2012-04-20)
Date: Fri, 12 Jul 2013 22:41:57 GMT
Connection: Keep-Alive

{"message_id":"518726r85010000001","message":"notification:info","payload":{"result":"The address is valid, and the shipment will be sent."}}```

The address is confirmed valid. Now let's try the invalid address.

```bash
$ curl --data @./bad_address.json -i -X POST -H 'Content-type:application/json' http://localhost:9292/validate_address

=> HTTP/1.1 200 OK
Content-Type: application/json;charset=utf-8
Content-Length: 130
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/1.9.3/2012-04-20)
Date: Fri, 12 Jul 2013 22:42:49 GMT
Connection: Keep-Alive

{"message_id":"518726r85010000001","message":"notification:error","payload":{"result":"This order is outside our shipping zone."}}```

As we expected, the address is reported as invalid.

## Accessing Custom Data