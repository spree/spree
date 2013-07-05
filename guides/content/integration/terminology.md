---
title: Terminology
---

## Integrations

## Messages

Messages are the core of the Integrator platform. A single action within a Spree store can result in several discrete Messages being sent to multiple End Points. A Messages can be created in one of two ways:

1. Indirectly as the result of events within a Spree store which are then discovered by the Integrator when it polls the store.  Examples of such events are new customers, orders and shipments.
2. In response to a Message that is being processed by an Endpoint.

### Attributes

Every Messages contains (at least) the following details:

| Attribute       | Description               |
| :---------------| :-------------------------|
| **message**     | This key represents the Message Type, in colon notation for example: `order:new`, `order:updated`, `user:new`, `shipment:ready`  |
| **message_id**  | A unique id (BSON::ObjectId) for the Message. |
| **payload**     | The payload contains all Message specific details, for example in the case of `order:new` it would contain Order details.  |

### Example

The following is an example of the JSON representation of a typical message:

<pre class="headers"><code>Basic message fields</code></pre>
<%= json :message %>

## Endpoints

Endpoints are small standalone web applications that can be subscribed to certain Message Types. The integrator delivers and tracks each Message as a Service Request is sent to all of its subscribed Endpoints. The Integrator includes lots of existing Endpoints for popular services and applications, but you can also create custom or private Endpoints to help integrate with proprietary systems.

Any message within the Integrator can be consumed by an Endpoint, with each individual Message resulting in a JSON encoded Message being sent via an HTTP POST request to a pre-configured Endpoint URL.

Using the Integrator's control panel, you can configure a list of the Message Types you want to subscribe to and a list of corresponding Endpoint URLs that will process them.

## Services

### Service Requests

### Service Responses

## Mappings

## Identifiers

## Parameters

## Log Entries

## Schedulers

Pollers are responsible for monitoring a Spree store's API for changes and converting these changes to new messages as events are detected. This polling approach simplifies integration from a store owner's perspective as there are no components of the Integrator operating within the Spree store itself.

The Poller also provides a heart beat monitor for a store which can raise alerts quickly when failures occur.