---
title: Returning Parameters From an Endpoint
---

There may be times when you need to return more from an endpoint than just a message status code and a message description. For example, you might need to pass back a refreshed authentication token from a service that uses OAuth and have the Hub store the refreshed token. You might need to pass back a shipment confirmation number from your fulfillment service so that your store can be updated with this information. The Hub has an easy, built-in technique for dealing with these types of situations.

## Prerequisites

This tutorial is an extension of the code used in the [Fulfillment Integration Tutorial](fulfillment_integration_tutorial) and is available on [Github](https://github.com/spree/integration_tutorials/tree/master/return_params). This tutorial assumes that you have [installed bundler](http://bundler.io/#getting-started) and Sinatra, and that you have a working knowledge of [Ruby](http://www.ruby-lang.org/en/), [JSON](http://www.json.org/), [Sinatra](http://www.sinatrarb.com/), and [Rack](http://rack.rubyforge.org).

## Steps

### Organization

Before we get too far along, let's do a little bit of organization of our files. Up to this point, we've stored our endpoint, the sample JSON files, and supporting files all in the same directory. That gets cumbersome fast, and it doesn't mirror what typically happens with real endpoints. 

Inside your endpoint directory, create a ```lib``` folder. Move the ```dummy_ship.rb``` API file and the ```shipment.rb``` Shipment class file to this directory.

Within your ```fulfillment_endpoint.rb``` file, add this line just below ```require 'endpoint_base'```:

```ruby
Dir['./lib/*.rb'].each { |f| require f }
```

This will automatically include the ```dummy_ship.rb``` and ```shipment.rb``` files in your application, meaning that you can trim your ```config.ru``` file down to just the following:

```ruby
require './fulfillment_endpoint'

run FulfillmentEndpoint
```

Next, create a ```samples``` directory inside your endpoint's root directory. Move the ```good_address.json``` and ```bad_address.json``` files to this folder.

### Returning Custom Parameters

[In the previous tutorial](fulfillment_integration_tutorial#return-multiple-messages), you learned to return the tracking number as part of the message's payload. Now, you will learn to encode it as a parameter. When you return the number this way, the Hub is actually smart enough to record the key/value pair in your integration so that this and other endpoints can make use of it.

Rewrite your ```/drop_ship``` method as follows:

```ruby
  post '/drop_ship' do
    get_address
    @order = @message[:payload]['order']

    begin
      result = DummyShip.ship_package(@address, @order)
      process_result 200, { 'message_id' => @message[:message_id], 
        'notifications' => [
          { 'level' => 'info', 'subject' => '',
            'description' => 'The address is valid, and the shipment has been sent.' }
        ],
        'parameters' => [
          { 'name' => 'tracking_number', 'value' => result.tracking_number },
          { 'name' => 'ship_date', 'value' => result.ship_date }
        ]
      }
    rescue Exception => e
      process_result 200, { 'message_id' => @message[:message_id],
        'notifications' => [
          { 'level' => "error", 'subject' => 'address is invalid',
            'description' => e.message } 
        ]
      }
    end
  end
```

As you can see, the ```tracking_number``` and ```ship_date``` are now each a key within a hash, and both hashes are members of the ```parameters``` array, which is returned when your endpoint runs the ```process_result``` method.

Let's see that in action. Start up your server.

```bash
$ bundle exec rackup -p 9292
```

Then, in a separate browser window, run the following curl command:

```bash
$ curl --data @./samples/good_address.json -i -X POST -H \
  'Content-type:application/json' http://localhost:9292/drop_ship

HTTP/1.1 200 OK 
Content-Type: application/json;charset=utf-8
Content-Length: 254
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/2.0.0/2013-06-27)
Date: Fri, 11 Oct 2013 01:49:32 GMT
Connection: Keep-Alive

{"message_id":"518726r85010000001","notifications":[{"level":"info","subject":"", \
  "description":"The address is valid, and the shipment will be sent."}], \
  "parameters":[{"name":"tracking_number","value":"S040042"},{"name":"ship_date", \
  "value":"2013-10-10"}]}
```

As you can see, the ```parameters``` array is now present and populated with the tracking number and ship date of our new package.

Because we still validate the shipping address before we create the shipment and its tracking number, when we run the curl command supplying the "bad" address file:

```bash
$ curl --data @./samples/bad_address.json -i -X POST -H \
  'Content-type:application/json' http://localhost:9292/drop_ship
```

we still get the correct returned message:

```bash
HTTP/1.1 200 OK 
Content-Type: application/json;charset=utf-8
Content-Length: 159
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/2.0.0/2013-06-27)
Date: Fri, 11 Oct 2013 01:56:16 GMT
Connection: Keep-Alive

{"message_id":"518726r85010000001","notifications":[{"level":"error","subject": \
  "address is invalid","description":"This order is outside our shipping zone."}]}
```