---
title: Creating Endpoints
---

## Prerequisites

This tutorial assumes that you have installed bundler and Sinatra, and that you have a working knowledge of [Ruby](http://www.ruby-lang.org/en/), [JSON](http://www.json.org/), [Sinatra](http://www.sinatrarb.com/), and [Rack](http://rack.rubyforge.org).

For detailed information about Endpoints, check out the <%= link_to "endpoints", "overview", "endpoints" %> section of the Overview guide.

### Hello, World!

Let's start by creating an extremely basic endpoint. To build this first endpoint, we'll use Sinatra - a simple lightweight web server.

```bash
mkdir myapp
cd myapp```

Within your new `myapp` directory, you will need a few files:

<pre class="headers"><code>Gemfile</code></pre>
```ruby
source 'https://rubygems.org'

gem 'rack'
gem 'sinatra'
gem 'sinatra-contrib'
gem 'json'
gem 'multi_json'```

<pre class="headers"><code>config.ru</code></pre>
```ruby
require './myapp'
run Sinatra::Application```

<pre class="headers"><code>myapp.rb</code></pre>
```ruby
require 'sinatra'
require 'sinatra/json'
require 'json'
require 'multi_json'

post '/' do
  message = JSON.parse(request.body.read)
  json 'message_id' => message['message_id']
end```

This is enough to function as an endpoint that echoes back the `message_id` of the message you pass. To test our endpoint, we need to create a fictional JSON message.

<pre class="headers"><code>give_id.json</code></pre>
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
}```

Launch your Sinatra server.

```bash
rackup```

Test your new endpoint by running the following curl command:

```bash
curl --data @./give_id.json -i -X POST -H 'Content-type:application/json' http://localhost:9292```

You should see the `message_id` returned.

<div class='warning'>Sinatra doesn't reload after changes by default; you will need to stop and restart your server any time you change your application. There is a <%= link_to 'Sinatra Reloader', 'http://www.sinatrarb.com/contrib/reloader' %> gem, but the use of it is beyond the scope of this tutorial.</div>

### Using EndpointBase

The easiest way to write an endpoint is to have it inherit from the [Endpoint Base](https://github.com/spree/endpoint_base) library.

```ruby
class SimpleEndpoint < EndpointBase
  post '/' do
    message = JSON.parse(request.body.read)
    json 'message_id' => message['message_id']
  end
end```

This endpoint will take an incoming message from the Spree Integrator, and return the message_id in JSON format.

For more info about Sinatra....

### Getting More Info Returned

<< Get shipment message as event>>

### Getting Even More Info

<< Get shipment message as event and new message.>>
