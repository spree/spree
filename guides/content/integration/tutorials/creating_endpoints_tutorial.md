---
title: Creating Endpoints
---

## Prerequisites

This tutorial assumes that you have [installed bundler](http://bundler.io/#getting-started) and Sinatra, and that you have a working knowledge of [Ruby](http://www.ruby-lang.org/en/), [JSON](http://www.json.org/), [Sinatra](http://www.sinatrarb.com/), and [Rack](http://rack.rubyforge.org).

***
For detailed information about Endpoints, check out the [endpoints](terminology#endpoints) section of the Terminology guide.
***

+++
The source code for the [Endpoint Creation Tutorial](https://github.com/spree/hello_endpoint/tree/master/create_endpoint_tutorial) (along with all of the integration tutorials) is available on Github.
+++

## Steps

### Hello, World!

Let's start by creating an extremely basic endpoint. To build this first endpoint, we'll use Sinatra - a useful tool for creating lightweight Ruby web applications.

```bash
$ mkdir hello_endpoint
$ cd hello_endpoint
```

Within our new `hello_endpoint` directory, we'll need a few files:

---Gemfile---
```ruby
source 'https://rubygems.org'

gem 'rack'
gem 'sinatra'
gem 'sinatra-contrib'
gem 'json'
gem 'multi_json'
```

---config.ru---
```ruby
require './hello_endpoint'
run Sinatra::Application
```

---hello_endpoint.rb---
```ruby
require 'sinatra'
require 'sinatra/json'
require 'json'
require 'multi_json'

post '/' do
  message = JSON.parse(request.body.read)
  json 'message_id' => message['message_id']
end
```

This is enough to function as an endpoint that echoes back the `message_id` of the message you pass. To test our endpoint, we need to create a fictional JSON message.

---give_id.json---
```json
{
  "message": "product:new",
  "message_id": "518726r84910000001",
  "payload": {
    "product": {
      "id": "92674",
      "name": "Really Awesome Widgets"
    }
  }
}
```

Launch your Sinatra application on rack:

```bash
$ bundle exec rackup -p 9292
```

Test your new endpoint by running the following curl command:

```bash
$ curl --data @./give_id.json -i -X POST -H 'Content-type:application/json' http://localhost:9292
```

You should see the `message_id` returned as part of the endpoint's payload message, as follows:

```bash
HTTP/1.1 200 OK
Content-Type: application/json;charset=utf-8
Content-Length: 35
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/1.9.3/2012-04-20)
Date: Tue, 02 Jul 2013 20:12:23 GMT
Connection: Keep-Alive

{"message_id":"518726r84910000001"}
```

So, great - we have success! But surely, there must be an easier way, right? Let's simplify our example by using Spree's [Endpoint Base](https://github.com/spree/endpoint_base) library. We just need to change our endpoint's relevant files, as follows:

---Gemfile---
```ruby
source 'https://rubygems.org'

gem 'endpoint_base', github: 'spree/endpoint_base'
```

---hello_endpoint.rb---
```ruby
require 'endpoint_base'
require 'multi_json'

class HelloEndpoint < EndpointBase
  post '/' do
    process_result 200, { 'message_id' => @message[:message_id] }
  end
end
```

---config.ru---
```ruby
require './hello_endpoint'
run HelloEndpoint
```

Install the new gem and restart your application:

```bash
$ bundle install
$ bundle exec rackup -p 9292
```

***
Sinatra doesn't reload after changes by default; you will need to stop and restart your server any time you change your application. There is a [Sinatra Reloader](http://www.sinatrarb.com/contrib/reloader) gem, but the use of it is beyond the scope of this tutorial.
***

Now, when you re-run the curl command:

```bash
$ curl --data @./give_id.json -i -X POST -H 'Content-type:application/json' http://localhost:9292
```

you should still get the same output:

```bash
HTTP/1.1 200 OK
Content-Type: application/json;charset=utf-8
Content-Length: 35
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/1.9.3/2012-04-20)
Date: Wed, 03 Jul 2013 01:41:01 GMT
Connection: Keep-Alive

{"message_id":"518726r84910000001"}
```

### Simple Notification Message

The `message_id` is the minimum information an endpoint has to return in a message it passes to the Integrator. In the first example above, that's all that was returned. Now let's move to passing a simple Notification Message in response.

***
For more information about Messages, be sure to read the [Integration Terminology Guide](terminology) thoroughly.
***

In the `get_id.json` message that we passed to our endpoint, we indicated with the `product:new` value that we've added a new product to our store. Let's assume that our `HelloEndpoint` endpoint interfaces with a supplier's catalog, and we want to know if the supplier stocks a similar item. We need to add to the logic in our endpoint:

---hello_endpoint.rb---
```ruby
require 'endpoint_base'
require 'multi_json'

class HelloEndpoint < EndpointBase
  post '/' do
    process_result 200, { 'message_id' => @message[:message_id] }
  end

  post '/product_existence_check' do
    product_names = JSON.parse(File.read("product_catalog.json"))['products'].map{|p| p["name"]}

    if product_names.include?(@message[:payload]['product']['name'])
      process_result 200, { 'message_id' => @message[:message_id], 'message' => 'notification:info' }
    else
      process_result 200, { 'message_id' => @message[:message_id], 'message' => 'notification:warn' }
    end
  end
end
```

!!!
We've added a new route to our endpoint, so we'll need to remember to update our curl command with the new URL path.
!!!

Now, let's create a dummy product catalog to query against, and a couple of new JSON files - one for a product that is in our supplier's catalog, and one that is not.

---product_catalog.json---
```json
{
  "products": [
    {
      "id": "1",
      "name": "Really Awesome Widgets",
      "price": "10.00"
    },
    {
      "id": "2",
      "name": "Somewhat Less Awesome Widgets",
      "price": "8.00"
    }
  ]
}
```

---in_stock_product.json---
```json
{
  "message": "product:new",
  "message_id": "518726r84910000015",
  "payload": {
    "product": {
      "id": "92675",
      "name": "Somewhat Less Awesome Widgets"
    }
  }
}
```

---not_in_stock_product.json---
```json
{
  "message": "product:new",
  "message_id": "518726r84910000004",
  "payload": {
    "product": {
      "id": "92676",
      "name": "Widgets Without Awesomeness"
    }
  }
}
```

Our `config.ru` and `Gemfile` files don't change.

We've laid the groundwork, so now it's time to test out our endpoint. First, let's pass it a product we know is in the catalog:

```bash
$ bundle exec rackup -p 9292
$ curl --data @./in_stock_product.json -i -X POST -H 'Content-type:application/json' http://localhost:9292/product_existence_check
```

Skipping the headers this time, you can see that the response we get is what we expect:

```bash
{"message_id":"518726r84910000015","message":"notification:info"}
```

Now, let's try a product our supplier does not carry. There is no need to restart rack here, since we haven't changed our endpoint.

```bash
$ curl --data @./not_in_stock_product.json -i -X POST -H 'Content-type:application/json' http://localhost:9292/product_existence_check

{"message_id":"518726r84910000004","message":"notification:warn"}
```

The good news is that our endpoint works! The bad news is that we'll have to source our "Widgets Without Awesomeness" somewhere else.

### Custom Message

Now that we know the product is in stock, it would be helpful if we knew how much it cost should we buy it from our supplier. For that, we need to once again add some logic to our endpoint.

---hello_endpoint.rb---
```ruby
require 'endpoint_base'
require 'multi_json'

class HelloEndpoint < EndpointBase
  post '/' do
    process_result 200, { 'message_id' => @message[:message_id] }
  end

  post '/product_existence_check' do
    if product_names.include?(passed_in_name)
      process_result 200, { 'message_id' => @message[:message_id], 'message' => 'notification:info' }
    else
      process_result 200, { 'message_id' => @message[:message_id], 'message' => 'notification:warn' }
    end
  end

  post '/query_price' do
    ## Find the product whose name matches what we're passing.
    if product = products.find { |product| product['name'] == passed_in_name }
      process_result 200, { 'message_id' => @message[:message_id], 'message' => 'product:in_stock',
        'payload' => { 'product' => { 'name' => product['name'], 'price' => product['price'] }}}
    else
      process_result 200, { 'message_id' => @message[:message_id], 'message' => 'product:not_in_stock' }
    end
  end

private
  def product_names
    @product_names ||= products.map { |product| product["name"] }
  end

  def products
    @products ||= JSON.parse(File.read("product_catalog.json"))['products']
  end

  def passed_in_name
    @passed_in_name ||= @message[:payload]['product']['name']
  end
end
```

As you can see, some of the code from our previous example was extracted out to reuse with this new request scenario.

If the product exists in the catalog, our endpoint returns a message with a success code (200), the `message_id` of our passed-in JSON, a `message` of `product:in_stock` and the name and price of the matching product in the catalog.

```bash
$ bundle exec rackup -p 9292
$ curl --data @./in_stock_product.json -i -X POST -H 'Content-type:application/json' http://localhost:9292/query_price

{"message_id":"518726r84910000015","message":"product:in_stock","payload":{"product":{"name":"Somewhat Less Awesome Widgets","price":"8.00"}}}
```

If the product doesn't exist in the catalog, our endpoint still returns a message with a success code and our referenced `message_id`, but the `message` key's value is now `product:not_in_stock`, and of course, there is no product in the payload.

```bash
$ curl --data @./not_in_stock_product.json -i -X POST -H 'Content-type:application/json' http://localhost:9292/query_price

{"message_id":"518726r84910000004","message":"product:not_in_stock"}
```