---
title: Creating Endpoints
---

## Creating Endpoints

Many sample <%= link_to "endpoints", "overview", "endpoints" %> for commonly-used third-party services are [already available](/todo) for your use. In most cases, you need only change your authorization credentials for these endpoints to work with your integration.

    TODO: Add a list with links to existing OSS EPs.

For those cases in which a sample endpoint doesn't already exist, you can easily write your own. An endpoint's job is to pass JSON messages between the Spree Integrator and the third-party service, so you need to make sure it includes all of the information it will need to accomplish that.

### Hello, World!

Let's start by creating an extremely basic endpoint - a "Hello, World" example. The easiest way to write an endpoint is to have it inherit from the [Endpoint Base](https://github.com/spree/endpoint_base) library.

```ruby
class SimpleEndpoint < EndpointBase
  post '/' do
    message = JSON.parse(request.body.read)
    json 'message_id' => message['message_id']
  end
end```

This endpoint will take an incoming message from the Spree Integrator, and return the message_id in JSON format.