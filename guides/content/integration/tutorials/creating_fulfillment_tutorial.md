---
title: Creating a Fulfillment Integration
---

## Prerequisites

This tutorial assumes that you have [installed bundler](http://bundler.io/#getting-started) and Sinatra, and that you have a working knowledge of [Ruby](http://www.ruby-lang.org/en/), [JSON](http://www.json.org/), [Sinatra](http://www.sinatrarb.com/), and [Rack](http://rack.rubyforge.org).

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

### Make the API Call

### Return Multiple Messages