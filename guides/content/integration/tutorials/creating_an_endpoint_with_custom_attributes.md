---
title: Creating an Endpoint with Custom Attributes
---

## Introduction

One of the greatest things about both the Spree Commerce storefront is its flexibility. Using this full-featured open source e-commerce package means that you have total freedom to customize it to suit your business' own special needs.

The Spree Commerce hub extends the customizations you make in your storefront's schema so that you can make use of them within your third-party services.

In this tutorial, you will:

* create a sandbox storefront,
* add custom attributes to it,
* extend the storefront's JSON output to include the new attributes,
* create a custom endpoint for a fictional third-party service, and
* use this endpoint to access and utilize your storefront's custom attributes.

## Prerequisites

This tutorial assumes that you have installed [bundler](http://bundler.io/#getting-started) and [Sinatra](http://www.sinatrarb.com/intro.html), and that you have a working knowledge of [Ruby](http://www.ruby-lang.org/en/), [JSON](http://www.json.org/), [Sinatra](http://www.sinatrarb.com/), and [Rack](http://rack.rubyforge.org). It also assumes that you are using Rails 4 and Ruby 2.0.

## Creating a Sandbox Store

First, clone the `spree` gem:

```bash
$ git clone https://github.com/spree/spree.git
```

Then go into this new `spree` directory and run the following command to generate the sandbox app:

```bash
$ bundle exec rake sandbox
```

This creates the sandbox Spree Commerce storefront, complete with sample data and a default admin user, with the username **spree@example.com** and password **spree123**.

## Adding Custom Attributes to Storefront

Suppose that the nature of your business is such that you often sell products to businesses rather than solely to individuals. Suppose further than the fulfillment company you use handles shipments to businesses differently than those to home addresses. This scenario requires that you add a new `variety` attribute to your storefront's `Address` objects.

***
A `type` attribute would work nicely here, but since `type` is a reserved word in ActiveRecord, and we want our frontend to continue to function flawlessly, we have to go with a different term. The customer will never know the difference, since we can still use "Address Type" as our input's label.
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

Of course, we need to add this field to the checkout form so customers can indicate the type of address. The checkout form resides within the `spree` gem at `/frontend/app/views/spree/address/_form.html.erb`, the relevant portion of which is:

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

We're going to use the [deface gem](https://github.com/spree/deface) to make changes to the `spree` files. Create a new file at `/app/overrides/spree/address/_form/address_variety_override.html.erb.deface` and include the following content:

```erb
<!-- insert_top 'div.inner' -->
<p class="field" id=<%%="#{address_id}variety" %>>
  <%%= form.label :variety, Spree.t(:variety) %><br />
  <%%= form.select :variety, ["Residence", "Business", "Other"] %>
</p>
```

$$$
Input the translation for t.variety above into localeapp.
$$$

Now, when you go to your storefront and check out, you should see the new select box at the address entry step.

![Variety Select Box](/images/integration/address_variety_select.jpg)

Given that we will be selling to business addresses, we should enable the site-wide setting to show the "Company" field in the address section of checkout. Open the `/config/initializers/spree.rb` file. Update the `config` block as follows:

```ruby
Spree.config do |config|
  config.company = true
end
```

***
To learn more about the storefront's built-in preferences, see the [Preferences guide](/developer/preferences).
***

Save your changes, then stop and restart your server to load the new configuration information. Now, when you go to checkout, you will see the new "Company" field.

![Company Field at Checkout](/images/integration/company_field_checkout.jpg)

## Extending JSON Output

Once you [get connected to the Spree Commerce hub](configuration), it will periodically poll your storefront for any relevant new or updated information based on the [integrations](supported_integrations) you have enabled. This information is transmitted using a standardized [JSON format](terminology#messages) and includes all of the information from a basic Spree Commerce storefront, per the [Spree::Api::ApiHelpers class](https://github.com/spree/spree/blob/master/api/app/helpers/spree/api/api_helpers.rb). 

It will not include any customized attributes. To extend the JSON output to include your custom attributes, you need to decorate the `ApiHelpers` class within your project. Create a file at `/app/helpers/spree/api/api_helpers_decorator.rb` and update it as follows:

```ruby
Spree::Api::ApiHelpers.class_eval do
  def address_attributes_with_variety
    address_attributes_without_variety << :variety
  end

  alias_method_chain :address_attributes, :variety
end
```

Then, when your storefront's orders are output, you'll see the custom `variety` field in the JSON file (much of the output is omitted below for brevity).

```json
{
  "message": "order:new",
  "payload": {
    "order": {
      "id": 12345,
      "number": "R123456789",
      "line_items": [ ... ],
      "ship_address": {
        "firstname": "John",
        "lastname": "Smith",
        "address": "123 Main St.",
        "variety": "Residence"
      }
    }
  }
}
```

We can use `curl` to verify our order output format. To do so, you'll first need to get an API authentication token. Go to your Admin Interface and click the "Users" tab. Click the "Edit" icon next to your name. You should see the API key for your user, but if you don't you can clear and regenerate it.

![User Edit Page for API Key Access](/images/integration/user_api_key.jpg)

Running the following command:

```bash
$ curl --header "X-Spree-Token: 31849d29d5d1323da1867981e36500a13826d9fdc701f66c" http://localhost:3000/api/orders.json
```

## Creating Custom Endpoint

In the [Creating a Fulfillment Endpoint Tutorial](creating_fulfillment_tutorial), we made a basic endpoint that had some simple logic relating to shipments. In this tutorial, we'll create a similar fulfillment endpoint. In [the next section](#accessing-custom-data), we'll extend it to account for the custom attribute and take different actions accordingly.

First, we need a new directory to house our integration files.

```bash
$ mkdir custom_attribute_endpoint
$ cd custom_attribute_endpoint
```

Within this directory, we'll create a fake API with which to interact, called `DummyShip`.

---dummy_ship.rb---
```ruby
module DummyShip
  def self.validate_address(address)
    ## Zipcode must be within a given range.
    unless (20170..20179).to_a.include?(address['zipcode'].to_i)
      raise "This order is outside our shipping zone."
    end
  end
end
```

We also need to create files to support our endpoint:

---Gemfile---
```ruby
source 'https://rubygems.org'

gem 'endpoint_base', github: 'spree/endpoint_base'
```

---config.ru---
```ruby
require './custom_attribute_endpoint'
require './dummy_ship'

run CustomAttributeEndpoint
```

---custom_attribute_endpoint.rb---
```ruby
require 'endpoint_base'

class CustomAttributeEndpoint < EndpointBase
  post '/validate_address' do
    address = @message[:payload]['order']['ship_address']

    begin
      result = DummyShip.validate_address(address)
      process_result 200, { 'message_id' => @message[:message_id], 'message' => "notification:info",
        "payload" => { "result" => "The address is valid, and the shipment will be sent." } }
    rescue Exception => e
      process_result 200, { 'message_id' => @message[:message_id], 'message' => "notification:error",
        "payload" => { "result" => e.message } }
    end
  end
end
```

The `validate_address` service will accept an incoming JSON file, compare the passed-in `ship_address` to the `DummyShip` API's `validate_address` method, and return a `notification:info` message for a valid address, or a rescued exception for an invalid address.



$$$
Extract the JSON from the storefront and run it through the endpoint.
$$$






## Accessing Custom Data

Our endpoint up to this point doesn't make use of our custom attributes at all. Let's add that functionality now.

---custom_attribute_endpoint.rb---
```ruby
require 'endpoint_base'

class CustomAttributeEndpoint < EndpointBase
  post '/validate_address' do
    address = @message[:payload]['order']['ship_address']

    begin
      result = DummyShip.validate_address(address)
      process_result 200, { 'message_id' => @message[:message_id], 'message' => "notification:info",
        "payload" => { "result" => "The address is valid, and the shipment will be sent." } }
    rescue Exception => e
      process_result 200, { 'message_id' => @message[:message_id], 'message' => "notification:error",
        "payload" => { "result" => e.message } }
    end
  end

  post '/get_home_signer'
end
```
