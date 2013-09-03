---
title: Terminology
---

## Integrations

An integration is a collection of [services](#services) that provide support for connecting your storefront to third-party or in-house applications, like Amazon, Mandrill, Quickbooks, Quiet Logistics and many more.

Each integration is generally provided by a single [endpoint](#endpoints) application, that are responsible for processing JSON [messages](#messages) that are POST'd to it and relaying the information to the third-party systems.

## Messages

Messages are the core of the Spree Commerce hub. A single action within a storefront can result in several discrete Messages being sent to multiple Endpoints. A Message can be created in one of two ways:

1. Indirectly as the result of events within a Spree Commerce storefront which the hub discovers when it polls the store. Examples of such events are new customers, orders, and shipments.
2. In response to a Message that is being processed by an Endpoint.

### Attributes

Every Message contains (at least) the following details:

| Attribute       | Description               |
| :---------------| :-------------------------|
| **message**     | This key represents the Message type, in colon notation for example: `order:new`, `order:updated`, `user:new`, `shipment:ready` |
| **message_id**  | A unique id (BSON::ObjectId) for the Message. |
| **payload**     | The payload contains all Message-specific details. For example, in the case of `order:new` it would contain Order details. |

### Example

The following is an example of the JSON representation of a typical message:

<pre class="headers"><code>Basic message fields</code></pre>
<%= json :message %>

## Endpoints

Endpoints are small standalone web applications that can be subscribed to certain Message types. Our hub delivers and tracks each Message as a Service Request is sent to all of its subscribed Endpoints. The Integrator includes lots of existing Endpoints for popular services and applications, but you can also create custom or private Endpoints to help integrate with proprietary systems.

Any Message within the Spree Commerce hub can be consumed by an Endpoint, with each individual Message resulting in a JSON-encoded Message being sent via an `HTTP POST` request to a pre-configured Endpoint URL.

Using the hub's control panel, you can configure a list of the Message types you want to subscribe to, and a list of corresponding Endpoint URLs that will process them.

## Services

Endpoints expose one or more Services to the outside world. Each Service maps to an `HTTP POST` method which is implemented in the Endpoint.

Take the following example from the [Hubspot Integration](hubspot_integration), which exposes a Service for recording new customers in Hubspot.

<pre class="headers"><code>hubspot_endpoint.rb</code></pre>
```ruby
class HubspotEndpoint < EndpointBase

  post '/record_customer' do
      base_message = { message_id: @message}

      begin
        importer = ContactImporter.new(@config, @message[:payload]['order']['actual'])
        importer.import

        response = base_message.merge({ success: 'Contact Updated' })
        code = 200
      rescue => e
        response = base_message.merge({ error: 'Coult not update contact' })
        code = 500
      end

      process_result code, response
  end
end
```

***
For more information on how Services communicate please see [Messaging Basics](messaging basics).
***

### Service Requests

A Service Request refers to the act of sending an `HTTP POST` to an Endpoint. Service Requests are automatically issued to the appropriate Endpoints based on user-defined Mappings. Behind the scenes, a Service Request looks something like this example, taken from the [Creating Endpoints Tutorial](creating_endpoints_tutorial):

```bash
POST /query_price HTTP/1.1
Host: localhost:9292
Accept: */*
Content-type:application/json
Content-Length: 169
```

***
If you are building your own Endpoint you may want to try some of the [Testing Tools](testing_tools) which provide a convenient way to send Service Requests to your Endpoint.
***

### Service Responses

A Service Response refers to the `HTTP Response` sent by an Endpoint in answer to a Service Request. Service Responses that execute successfully (without encountering an exception) will return a `200 OK` response. If the Endpoint encounters an exception while processing the Service Request, it should return a `5XX SERVER ERROR` response code. These types of Service Response will be considered [Failures](#failures).

Here's an example of a successful Service Response taken from the [Creating Endpoints Tutorial](creating_endpoints_tutorial):

```bash
HTTP/1.1 200 OK
Content-Type: application/json;charset=utf-8
Content-Length: 142
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/1.9.3/2011-10-30)

{"message_id":"518726r84910000015","message":"product:in_stock","payload":{"product":{"name":"Somewhat Less Awesome Widgets","price":"8.00"}}}
```

## Mappings

## Identifiers

## Parameters

## Failures

## Log Entries

## Schedulers

Pollers are responsible for monitoring a Spree Commerce storefront's API for changes and converting these changes to new messages as events are detected. This polling approach simplifies integration from a store owner's perspective, as there are no components of the Spree Commerce hub operating within the storefront itself.

The Poller also provides a heart beat monitor for a store which can raise alerts quickly when failures occur.
