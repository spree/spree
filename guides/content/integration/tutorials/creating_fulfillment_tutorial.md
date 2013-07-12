---
title: Creating a Fulfillment Integration
---

## Prerequisites

This tutorial assumes that you have [installed bundler](http://bundler.io/#getting-started) and Sinatra, and that you have a working knowledge of [Ruby](http://www.ruby-lang.org/en/), [JSON](http://www.json.org/), [Sinatra](http://www.sinatrarb.com/), and [Rack](http://rack.rubyforge.org).

+++
The source code for the [Fulfillment Tutorial](https://github.com/spree/hello_endpoint/tree/master/fulfillment_tutorial) (along with all of the integration tutorials) is available on Github.
+++

## Introduction

By now, you should be familiar with the basic concepts of [creating an endpoint](creating_endpoints_tutorial). In this tutorial, we'll walk through creating a fictional - yet more realistic - integration, complete with the [endpoint](terminology#endpoints), JSON request files, and even a dummy API we'll use to simulate our drop-shipper.

## Steps to Build the Integration

We will begin our integration with the simplest possible successful endpoint, and gradually add complexity and functionality.

### Create a Basic Endpoint

As with the more basic [endpoint creation tutorial](creating_endpoints_tutorial), we'll use the Spree [EndpointBase gem](https://github.com/spree/endpoint_base) to create our fulfillment endpoint.

To start with, we need a new directory to house our integration files.

```bash
$ mkdir fulfillment_endpoint
$ cd fulfillment_endpoint```

Within our new `fulfillment_endpoint` directory, we will obviously need to have files to make our integration work correctly. We'll need:

---Gemfile---
```ruby
source 'https://rubygems.org'

gem 'endpoint_base', github: 'spree/endpoint_base'```

***
Throughout this tutorial, nothing changes in our `Gemfile`, so it will not be re-shown.
***

---config.ru---
```ruby
require './fulfillment_endpoint'
run FulfillmentEndpoint```

---fulfillment_endpoint.rb---
```ruby
require 'endpoint_base'
require 'multi_json'

class FulfillmentEndpoint < EndpointBase
  post '/drop_ship' do
    process_result 200, { 'message_id' => @message[:message_id] }
  end
end```

This is already enough to function as a working endpoint. Let's create a sample incoming JSON file.

---return_id.json---
```json
{
  "message_id": "518726r85010000001",
  "payload": {
  }
}```

Now install the gems, and start the Sinatra server.

```bash
$ bundle install
$ bundle exec rackup -p 9292```

Open a new Terminal window, navigate to the /fulfillment_endpoint directory, and run:

```bash
$ curl --data @./return_id.json -i -X POST -H 'Content-type:application/json' http://localhost:9292/drop_ship

=> HTTP/1.1 200 OK
Content-Type: application/json;charset=utf-8
Content-Length: 35
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/1.9.3/2012-04-20)
Date: Wed, 10 Jul 2013 16:47:31 GMT
Connection: Keep-Alive

{"message_id":"518726r84910000001"}```

The output (including headers, as we included the `-H` switch in our curl command) does exactly what we expect: it returns a success (200) status message along with the `message_id` of the JSON file we passed.

+++
The sample files for the preceding example are available on [Github](https://github.com/spree/hello_endpoint/tree/master/fulfillment_tutorial/basic_endpoint).
+++

### Make the API Call

This is great, as far as it goes, but it doesn't really show the power of the Spree Integrator. We want our Endpoints to interact with third-party services, not just return status messages. We can approximate this by writing a fake fulfillment API, called DummyShip.

---dummy_ship.rb---
```ruby
module DummyShip
  def self.validate_address(address)
    ## Zipcode must be within a given range.
    unless (20170..20179).to_a.include?(address['zipcode'].to_i)
      halt 406
    end
  end
end```

We'll need to require this API in our `config.ru` file.

---config.ru---
```ruby
require './fulfillment_endpoint'
require './dummy_ship'

run FulfillmentEndpoint```

Of course, we'll need to update our endpoint to interact with the API.

---fulfillment_endpoint.rb---
```ruby
require 'endpoint_base'
require 'multi_json'

class FulfillmentEndpoint < EndpointBase
  post '/drop_ship' do
    process_result 200, { 'message_id' => @message[:message_id] }
  end

  post '/validate_address' do
    address = @message[:payload]['order']['shipping_address']

    begin
      result = DummyShip.validate_address(address)
      process_result 200, { 'message_id' => @message[:message_id], 'message' => "notification:info",
        "payload" => { "result" => "The address is valid, and the shipment will be sent." } }
    rescue Exception => e
      process_result 200, { 'message_id' => @message[:message_id], 'message' => "notification:error",
        "payload" => { "result" => "There was a problem with this address." } }
    end
  end
end```

As you can see, our new `validate_address` service will accept an incoming JSON file and extract the shipping_address, storing it in the `address` variable. It then makes a call to our `DummyShip` API's `validate_address` method, passing in the `message` variable. If there are no exceptions, the endpoint returns a `notification:info` message with a payload indicating that all's well.

If there is an exception, however, the endpoint elegantly rescues the exception, and returns a `notification:error` message with a payload indicating that our address is not valid.

Our admittedly simplistic API does nothing more at this point than make sure the zip code we pass in is within a pre-defined range. If it's not, the API returns a 406 error ("Not Acceptable").

Now we just need a couple of JSON files we can try out. Let's make one that passes an order whose shipping address is within the range, and one which is not.

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

***
Remember: Sinatra doesn't reload your changes unless you explicitly tell it to. There is a [Sinatra Reloader](http://www.sinatrarb.com/contrib/reloader) gem you can try out on your own, if you like.
***

Time to test it out in curl. First, the address that our API considers valid:

```bash
$ bundle exec rackup -p 9292
$ curl --data @./good_address.json -i -X POST -H 'Content-type:application/json' http://localhost:9292/validate_address

=>HTTP/1.1 200 OK
Content-Type: application/json;charset=utf-8
Content-Length: 141
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/1.9.3/2012-04-20)
Date: Wed, 10 Jul 2013 23:09:47 GMT
Connection: Keep-Alive

{"message_id":"518726r85010000001","message":"notification:info","payload":{"result":"The address is valid, and the shipment will be sent."}}```

Hooray! Our shipment to Leesburg is a go! Now let's try the shipment to Greensboro.

```bash
$ curl --data @./bad_address.json -i -X POST -H 'Content-type:application/json' http://localhost:9292/validate_address

=> HTTP/1.1 200 OK
Content-Type: application/json;charset=utf-8
Content-Length: 128
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/1.9.3/2012-04-20)
Date: Wed, 10 Jul 2013 23:11:16 GMT
Connection: Keep-Alive

{"message_id":"518726r85010000001","message":"notification:error","payload":{"result":"There was a problem with this address."}}```

As we expected, the zip code for this order is outside the API's acceptable range; this shipment can not be sent with the `DummyShip` fulfillment process.

+++
The sample files for the preceding example are available on [Github](https://github.com/spree/hello_endpoint/tree/master/fulfillment_tutorial/dummy_ship).
+++

### Return Multiple Messages

We have definitely taken some steps toward more useful functionality, but the real beauty of the Spree Integrator is in the way one incoming message can have a ripple effect of several actions and messages to a variety of endpoints and their third-party services.

In reality, it wouldn't be enough to know that the address was valid. If the address is valid, we want our DummyShip fulfiller to ship the package and return the shipment information in a new `shipment:confirm` message. If we have an integration with [Mandrill](http://mandrill.com/) or some other email-sending platform, we can have _that_ integration's endpoint watch for `shipment:confirm` messages, and send an email to our customer reassuring them that their purchase is on the way.

The key to this process is in getting our fulfillment endpoint to generate just such a message. We can accomplish that with only a few tweaks to our integration files.

---config.ru---
```ruby
require './fulfillment_endpoint'
require './dummy_ship'
require './shipment'

run FulfillmentEndpoint```

The `Shipment` class we included above will be used to represent an actual outgoing package for our `DummyShip` fulfiller.

---shipment.rb---
```ruby
class Shipment
  attr_reader :tracking_number, :mailing_address, :ship_date

  def initialize(order)
    ## This method runs when the new method is called on a Shipment object.
    @tracking_number = generate_shipment_number
    @mailing_address = order['shipping_address']
    @ship_date = Date.today
  end

  def generate_shipment_number
    "S#{Array.new(6){rand(6)}.join}"
  end
end```

Now our fake API needs to get more complex, since it's going to be doing more interesting things.

---dummy_ship.rb---
```ruby
module DummyShip
  def self.ship_package(address, order)
    validate_address(address)
    Shipment.new(order)
  end

  def self.validate_address(address)
    ## Zipcode must be within a given range.
    unless (20170..20179).to_a.include?(address['zipcode'].to_i)
      halt 406
    end
  end
end```

Naturally, our endpoint will need to have a service that taps into all this cool API functionality. Rather than writing a new service, it's more logical to change the `/drop_ship` service we wrote in the [first section of this tutorial](#create-a-basic-endpoint).

---fulfillment_endpoint.rb---
```ruby
require 'endpoint_base'
require 'multi_json'

class FulfillmentEndpoint < EndpointBase
  post '/drop_ship' do
    get_address
    @order = @message[:payload]['order']
    begin
      result = DummyShip.ship_package(@address, @order)
      process_result 200, [ { 'message_id' => @message[:message_id], 'message' => "notification:info",
        "payload" => { "result" => "The address is valid, and the shipment will be sent." } },
        { 'message_id' => @message[:message_id], 'message' => "shipment:confirm",
        "payload" => { "tracking_number" => result.tracking_number, "ship_date" => result.ship_date } } ]
    rescue Exception => e
      process_result 200, { 'message_id' => @message[:message_id], 'message' => "notification:error",
        "payload" => { "result" => "There was a problem with this address." } }
    end
  end

  post '/validate_address' do
    get_address

    begin
      result = DummyShip.validate_address(@address)
      process_result 200, { 'message_id' => @message[:message_id], 'message' => "notification:info",
        "payload" => { "result" => "The address is valid, and the shipment will be sent." } }
    rescue Exception => e
      process_result 200, { 'message_id' => @message[:message_id], 'message' => "notification:error",
        "payload" => { "result" => "There was a problem with this address." } }
    end
  end

  def get_address
    @address = @message[:payload]['order']['shipping_address']
  end
end```

All that remains now is to test it! We can use the same `good_address.json` and `bad_address.json` files from the [preceding section of this tutorial](#make-the-api-call).

```bash
$ bundle exec rackup -p 9292
$ curl --data @./good_address.json -i -X POST -H 'Content-type:application/json' http://localhost:9292/drop_ship

=> HTTP/1.1 200 OKHTTP/1.1 200 OK
Content-Type: application/json;charset=utf-8
Content-Length: 128
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/1.9.3/2012-04-20)
Date: Thu, 11 Jul 2013 15:03:46 GMT
Connection: Keep-Alive

{"message_id":"518726r85010000001","message":"notification:error","payload":{"result":"There was a problem with this address."}}
Content-Type: application/json;charset=utf-8
Content-Length: 273
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/1.9.3/2012-04-20)
Date: Thu, 11 Jul 2013 15:00:40 GMT
Connection: Keep-Alive

[{"message_id":"518726r85010000001","message":"notification:info","payload":{"result":"The address is valid, and the shipment will be sent."}},{"message_id":"518726r85010000001","message":"shipment:confirm","payload":{"tracking_number":"S054334","ship_date":"2013-07-11"}}]```

As you can see, the endpoint returns an array of messages. The first is a `notification:info` like the ones we've used all along, basically just saying that the address is valid. The second is a `shipment:confirm` message that includes the new shipment's `tracking_number` and date of shipping. The tracking number is randomly-generated, so both it and the `ship_date` should be different from those shown above.

But what happens if we once again try to send in a shipment with a bad address?

```bash
$ curl --data @./bad_address.json -i -X POST -H 'Content-type:application/json' http://localhost:9292/drop_ship

=> HTTP/1.1 200 OK
Content-Type: application/json;charset=utf-8
Content-Length: 128
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/1.9.3/2012-04-20)
Date: Thu, 11 Jul 2013 15:03:46 GMT
Connection: Keep-Alive

{"message_id":"518726r85010000001","message":"notification:error","payload":{"result":"There was a problem with this address."}}```

Exactly what we want to have happen: the shipment is not created, the exception is captured elegantly, and a `notification:error` message is returned.

+++
The sample files for the preceding example are available on [Github](https://github.com/spree/hello_endpoint/tree/master/fulfillment_tutorial/multiple_messages).
+++