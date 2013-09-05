---
title: Terminology
---

This guide provides a summary of the terms often used when referencing the Spree Commerce hub. Most of the terms outlined here also have detailed guides covering them.

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

Endpoints are small standalone web applications that can be subscribed to certain Message types via Mappings. Our hub delivers and tracks each Message as a Service Request is sent to all of its subscribed Endpoints. The Integrator includes lots of existing Endpoints for popular services and applications, but you can also create custom or private Endpoints to help integrate with proprietary systems.

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

A Service Response refers to the `HTTP Response` sent by an Endpoint in answer to a Service Request. Service Responses that execute successfully (without encountering an exception) will return a `200 OK` response. If the Endpoint encounters an exception while processing the Service Request, it should return a `5XX SERVER ERROR` response code.

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

Mappings represent a subscription for specific message types to an endpoint's service, for example `order:new` to the Mandrill Order Confirmation service. Mappings include all the details required to provide routing, filtering, uniqueness protection and failure handling.

### Parameters

Parameters are store specific configuration values that are included with each Service Request as part of the Message payload. A single message may contain any number of parameters (including zero).

There are two main types of parameters:

| Attribute            | Description               |
| :--------------------| :-------------------------|
| **Single Value**     | These represent single pieces of configuration data like API keys, email addresses, etc, using one of the following datatypes: string, integer, float and boolean.
| **Lists Value**      | Lists are special parameters generally used to hold lookup tables for matching data for disparate systems, for example shipping methods between Amazon and Spree Commerce


#### Example List Parameter

```json
{
  "shipping_method.lookup": [
    { "standard": "US STANDARD",
      "expedited": "US STANDARD",
      "nextday": "OVERNIGHT",
      "secondday": "US 2 DAY EXPRESS"
    }
  ]
}
```

***
List parameters are arrays of hashes, this is intended to allow a single param to hold multiple related lookup tables for several mappings. 

For example a `shipping_method.lookup` param could hold two separate hashes for Amazon and one for Quickbooks.
***

### Identifiers

During the normal operation of the hub the same message can be created multiple times, for example a `shipment:ready` message is pushed for every update of an order where the order contains a shipment with a state of 'ready'. 

We do this to not limit the opportunity to act on a message to a single instance. In the case of the `shipment:ready` message you might not want to spend the shipment details to your 3PL until it has been marked as 'released'.

The first `shipment:ready` message would be generated when the `order:new` message gets processed, but at this point the `released_at` attribute would not be set (so a Filter would be used to prevent the mapping acting on the message). 

When the `released_at` attribute was set on your Spree Commerce storefront an `order:update` message would generate a second `shipment:ready` message which would meet the filter criteria and be sent to the endpoint.

Identifiers are then used to prevent duplicate messages from being sent to the same endpoint service more than once, by capturing key attributes from the message that indicate the message as unique (for example the order and shipment number in the case of a `shipment:ready` message). 

Identifiers have two key aspects:


| Attribute            | Description               |
| :--------------------| :-------------------------|
| Name                 | A variable name to hold the intended target value
| Path                 | An xpath style query to identify the target value

#### Example Identifiers

```json
"identifiers": {
  "order_number": "payload.order.number",
  "shipment_number": "payload.shipment.number"
}
```

### Filters

Filters are very similar to Identifiers and are used to highlight attributes within a message and check them against a predefined value before allowing the message to route to an endpoint's service.

Filters are made up of four key values:

| Attribute            | Description               |
| :--------------------| :-------------------------|
| Path                 | An xpath style query to identify the target value
| Operator             | A predefined list of comparison checks (see list below)
| Value                | The static value to use in the comparison
| Match Rule           | 'any' or 'all' target values must pass comparison, default: 'all'

The following filter Operator are available:

| Attribute            | Description               |
| :--------------------| :-------------------------|
| Equal (eq)           | Does a direct string comparison of the two values (==)
| Not Equal (neq)      | Opposite of above (!=)
| Greater than (gt)    | Converts both values to floats, and ensures the target value is greater than the static value (>)
| Less than (lt)       | Converts both values to floats, and ensures the target value is less than the static value (<)
| Begins With (begin)  | Ensures target values begins with the static value
| Contains (contains)  | Ensures target values contains the static value
| Ends With (end)      | Ensures target values ends with the static value
| Present (present)    | Ensures target values is not null, an empty string and does not == 'null'
| Empty (empty)        | Ensures target values is either null, an empty string or == 'null'
| Match (match)        | Static value must be a regex that matches on target value

#### Example Filters

```json
"filters": [
  {
    "path": "payload.order.status",
    "operator": "eq",
    "value": "complete"
  },
  {
    "path": "payload.order.totals.tax",
    "operator": "gt",
    "value": "100"
  },
  {
    "path": "payload.order.shipments.*.items.*.sku",
    "operator": "eq",
    "value": "ROR-0001",
    "match_rule": "any"
  },
]
```

### Failures

Mappings provide two methods of handling a message when it has failed (i.e. the endpoint returns a non HTTP 200 response).

The default approach is to retry automatically using an exponential back-off algorithm (i.e. the time between retries increases after each failure).

For some endpoint services where retrying a message could have potentially negative side-effects, automatic retries can be disabled effectively parking the message and requiring human intervention to allow it to retry or be manually archived.

## Notifications

Notifications are human readable event logs that can be returned by endpoints as a means of providing a summary of actions taken for a particular order, user, product, etc.

Notifications are also messages which can be mapped to other endpoints for processing (like logging tickets in Zendesk for failures or sending emails).

For more please review the [Notification Messages guide](/integration/notification_messages.html)

## Schedulers

Pollers are responsible for monitoring a Spree Commerce storefront's API for changes and converting these changes to new messages as events are detected. This polling approach simplifies integration from a store owner's perspective, as there are no components of the Spree Commerce hub operating within the storefront itself.

The Poller also provides a heart beat monitor for a store which can raise alerts quickly when failures occur.
