---
title: Overview
---

## Overview

The Integrator is a managed JSON based messaging service that connects a Spree store to numerous third-party applications and services. Any application capable of consuming or producing JSON encoded messages can operate within and extend the Integrator eco-system.

You'll see several terms used frequently when discussing the Integrator and it's components, processing and related systems. This guide explains the keys concepts of the Integrator platform:

## Messages

Messages are the core of the integrator platform, a single action with a Spree store can result in several discreet messages being produced and consumed. Messages can be created in two locations:

1. Within a Spree store as users complete actions like: customers signing up, completing checkouts, administrators processing orders or uploading new products.
2. Externally inside other systems, which then transmit those messages to the Integrator for processing. For more see ["Pushing Messages"](/integration/push/).

Every messages contains (at least) the following details:

* _message_ - This key represents the message type, in colon notation for example: _order:new_, _order:updated_, _user:new_, _shipment:ready_
* _message_id_ - A unique id (BSON::ObjectId) for the message.
* _payload_ - The payload contains all message specific details, for example in the case of _order:new_ it would contains orders details.

<pre class="headers"><code>Basic message fields</code></pre>
<%= json :message %>

## Queues

The Integrator consists of two internal queues that are used to manage the messages as they pass through the system:

* _Incoming_ - the Incoming queue accepts all messages as they are presented with on the most basic of validations. This ensures systems exchanging messages with the integrator can hand-off messages quickly.
* _Accepted_ - Once Incoming messages are validated, they are faned out creating a unique message destined for each subcriber consumer or endpoint. The Accepted queue hold all messages until they are successfully processed, when they are then archived.


## Endpoints

Endpoints are small standalone web applications that can be subscribed to certain message types. The integrator delivers and tracks each message as it's dispatched to all it's subscribed endpoints. The Integrator includes lots of existing endpoints for popular services and applications, but you can also create custom or private endpoints to help integrate with proprietary systems.

Any message with the Integrator can be consumed by an endpoint, with each individual message resulting in a JSON encoded message being dispatched via a HTTP POST request to a pre-configured endpoint URL.

Using the Integrator's control panel you can configure a list of the message types you want to subscribe to, and a list of corresponding endpoint URLs that will process them. For more see ["Consuming Messages"](/integration/consuming/).

## Consumers

Consumers are internal message handlers that review all messages and can conditionally decide to create (or push) new messages based on the reviewed message's payload. For example and _order:new_ message could be reviewed by a consumer that would check for canceled orders, if the order included in the _order:new_ message was already canceled then the consumer would also push a _order:canceled_ message.

This helps cut down on the amount of processing an endpoint who's only interest in canceled orders would have to do, as it could just subscribe to _order:canceled_, and ignore _order:new_ messages.

## Pollers

Pollers are responsible for monitoring a Spree store's API for changes and converting these changes to new messages as events are detected. This polling approach simplifies integration form a store owners perspective as there are no components of the Integrator operating within the Spree store itself.

The Poller also provides a heart beat monitor for a store, which can raise alerts quickly when failures occur.

## Events

Events are essentially logs entries regarding interesting details that maybe relevant to a store owner with regard to an order, product, user as messages were processed against them within the system.

Events are persistend and displayed with the Spree administration interface beside each associated object.
