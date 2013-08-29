---
title: Creating an Endpoint with Custom Attributes
---

## Introduction

One of the greatest things about the Spree Commerce storefront is its flexibility. Using this full-featured open source e-commerce package means that you have total freedom to customize it to suit your business' own special needs.

The Spree Commerce hub extends the customizations you make in your storefront's schema so that you can make use of them within your third-party services.

In this tutorial, you will:

* create a sandbox storefront,
* add custom attributes to it,
* extend the storefront's JSON output to include the new attributes,
* create a custom endpoint for a fictional third-party service, and
* use this endpoint to access and utilize your storefront's custom attributes.

## Prerequisites

This tutorial assumes that you have installed [bundler](http://bundler.io/#getting-started), and that you have a working knowledge of [Ruby](http://www.ruby-lang.org/en/), [JSON](http://www.json.org/), and [Rack](http://rack.rubyforge.org). It also assumes that you are using Rails 4 and Ruby 2.0.

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

```ruby
class AddVarietyFieldToAddresses < ActiveRecord::Migration
  def change
    add_column :spree_addresses, :variety, :string
  end
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
  <%%= form.label :variety, "Address Type" %><br />
  <%%= form.select :variety, ["Residence", "Business", "Other"] %>
</p>
```

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
$ curl --header "X-Spree-Token: your_spree_token" 
  http://yourdomain.com/api/orders.json
```

+++
If you are working in development mode, `yourdomain.com` is likely to be `localhost:3000`.
+++

Your output should look something like this:

```bash
{"count":3,"current_page":1,"pages":1,"orders":[{"id":1,"number":"R123456789",
"item_total":"15.99","total":"22.59","state":"complete","adjustment_total":"6.6",
"user_id":null,"created_at":"2013-08-28T18:20:19Z",
"updated_at":"2013-08-28T18:20:19Z","completed_at":"2013-08-27T18:20:19Z",
"payment_total":"0.0","shipment_state":"pending","payment_state":"balance_due",
"email":"spree@example.com","special_instructions":null,
"token":"d32f89f869d639a7"},{"id":2,"number":"R987654321","item_total":"22.99",
"total":"30.29","state":"complete","adjustment_total":"7.3","user_id":null,
"created_at":"2013-08-28T18:20:19Z","updated_at":"2013-08-28T18:20:19Z",
"completed_at":"2013-08-27T18:20:19Z","payment_total":"0.0",
"shipment_state":"pending","payment_state":"balance_due",
"email":"spree@example.com","special_instructions":null,
"token":"dcf341a8ca660bd4"}, {"id":3,"number":"R555208170","item_total":"15.99",
"total":"15.99","state":"cart","adjustment_total":"0.0","user_id":1,
"created_at":"2013-08-28T21:07:00Z","updated_at":"2013-08-28T21:07:03Z",
"completed_at":null,"payment_total":"0.0","shipment_state":null,
"payment_state":null,"email":"spree@example.com","special_instructions":null,
"token":"bd75e26374040274"}]}
```

None of this includes the details for a particular orders, so as yet, you don't see the custom fields. For that, we need to make a change to our API call:

```bash
$ curl --header "X-Spree-Token: your_spree_token" 
  http://yourdomain.com/api/orders/R123456789.json
```

This command fetches the details for the order with the number `R123456789`. The return is very long (orders complex objects), but the part we care about is there:

```bash
"ship_address":{"id":1,"firstname":"Retha","lastname":"Murray",
"full_name":"Retha Murray","address1":"8730 Dickens Keys","address2":"Apt. 049",
"city":"Karenburgh","zipcode":"16804","phone":"425-355-5233","company":null,
"alternative_phone":null,"country_id":49,"state_id":48,"state_name":null,
"variety":null,"country":{"id":49,"iso_name":"UNITED STATES","iso":"US",
"iso3":"USA","name":"United States","numcode":840},"state":{"id":48,
"name":"New York","abbr":"NY","country_id":49}}
```

The `variety` key is there in the output (line 5). There is no value for it, because the order was part of the seed data and so preceded our modifications, but our integrations can still see and make use of this attribute.

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
      process_result 200, { 'message_id' => @message[:message_id], 
        'message' => "notification:info", "payload" => { "result" => 
        "The address is valid, and the shipment will be sent." } }
    rescue Exception => e
      process_result 200, { 'message_id' => @message[:message_id], 
        'message' => "notification:error", "payload" => { "result" => 
        e.message } }
    end
  end
end
```

The `validate_address` service will accept an incoming JSON file, compare the passed-in `ship_address` to the `DummyShip` API's `validate_address` method, and return a `notification:info` message for a valid address, or a rescued exception for an invalid address.

We'll navigate to the custom_attribute_endpoint directory, install gems, start our Sinatra server, then run the following `curl` command to run the aforementioned order's JSON output through our new endpoint's `validate_address` service:

```bash
$ cd custom_attribute_endpoint
$ bundle install
$ bundle exec rackup -p 9292
$ curl --data http://localhost:3000/api/orders/R123456789.json -i -X POST -H 
  'Content-type:application/json' http://localhost:9292/validate_address
```

$$$
The command above returns a 406 because the JSON output from a Spree store isn't formatted how we need it. We need @message[:payload]['order'] but the whole JSON is the order. Need to get with Brian to figure out how to make this so; in the meantime, I wrote up a hard-coded JSON file with the order's JSON on it, and added that to the project.
$$$

Since the ZIP code for the shipping address on this order is 16804 - not inside our API's "acceptable" range, the return we get is:

```bash
HTTP/1.1 200 OK 
Content-Type: application/json;charset=utf-8
Content-Length: 117
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/2.0.0/2013-06-27)
Date: Wed, 28 Aug 2013 23:05:53 GMT
Connection: Keep-Alive

{"message_id":"12345","message":"notification:error","payload":{"result":"This order 
  is outside our shipping zone."}}
```

## Accessing Custom Data

Our endpoint up to this point doesn't make use of our custom attributes at all. Let's add that functionality now.

---custom_attribute_endpoint.rb---
```ruby
require 'endpoint_base'

class CustomAttributeEndpoint < EndpointBase
  post '/validate_address' do
    get_address    

    begin
      result = DummyShip.validate_address(@address)
      process_result 200, { 'message_id' => @message[:message_id], 'message' => 
        "notification:info", "payload" => { "result" => 
        "The address is valid, and the shipment will be sent." } }
    rescue Exception => e
      process_result 200, { 'message_id' => @message[:message_id], 'message' => 
        "notification:error", "payload" => { "result" => e.message } }
    end
  end

  post '/get_biz_signer' do
    get_address

    begin
      result = @address['variety'] == "Business" ? "do" : "do not"
      process_result 200, { 'message_id' => @message[:message_id], 'message' => 
        "notification:info", "payload" => { "result" => 
        "You #{result} need to get a signature for this package." } }
    rescue Exception => e
      process_result 200, { 'message_id' => @message[:message_id], 'message' => 
        "notification:error", "payload" => { "result" => e.message} }
    end
  end

  def get_address
    @address = @message[:payload]['order']['ship_address']
  end
end
```

So we've added a new service - `get_biz_signer` - to our endpoint. This endpoint verifies the value of the `variety` key in our order and returns a message whose payload indicates whether the fulfiller will or won't need to get a signature upon delivery.

We need to modify a couple of our storefront's sample orders to test this functionality. It's easiest to do that in the Admin Interface. Set the shipping address `variety` on the order with the number "R123456789" to "Business" and the order with the number "R987654321" to "Residence". Be sure to save your changes each time.

Now, navigate back to the custom_attribute_endpoint directory. When you run the curl command against the residential delivery:

```bash
$ curl --data http://localhost:3000/api/orders/R987654321.json -i -X POST -H 
  'Content-type:application/json' http://localhost:9292/get_biz_signer
```

you get the following return:

```bash
{"message_id":"12345","message":"notification:info","payload":{"result":
  "You do not need to get a signature for this package."}}```

Yet when you run it against the business delivery:

```bash
$ curl --data http://localhost:3000/api/orders/R123456789.json -i -X POST -H 
  'Content-type:application/json' http://localhost:9292/get_biz_signer
```

you get the following return:

```bash
{"message_id":"12345","message":"notification:info","payload":{"result":
  "You do need to get a signature for this package."}}
```

Through this relatively simplistic scenario, you get a sense of just how much flexibility you have in writing both storefronts and integrations to suit your particular needs.