---
title: Spree Integration Guide
---

## Overview

Integrating with Spree Professional is simple and uses basic HTTP calls to relay events to your system as they occur within a Spree store. This form of integration is often referred to as Web Hooks or HTTP Callbacks.

## Events and Messages

Spree Professional is an event driven system, events can be created in two locations:

1. Within a Spree store as users complete actions like: customers signing up, completing checkouts, administrators processing orders or uploading new products.
2. Externally inside other systems, which then transmit those events to Spree Professional for processing. For more see ["Pushing Events"](/pro/push/).

All events can be consumed by your integration endpoint, with each individual event resulting in a JSON encoded message being dispatched via HTTP to a pre-configured endpoint URL.

Using the Spree Professional control panel you can configure a list of the events you want to subscribe to, and a list of corresponding endpoint URLs that will process those events. For more see ["Consuming Events"](/pro/events/).

## Message Formats

All event messages contain the following details:

* _event_ - This key represents the event type, in colon notation for example: _order:new_, _order:updated_, _user:new_, _shipment:ready_
* _event_id_ - A unique id for the message.
* _payload_ - The payload contains all message specific details, for example in the case of _order:new_ it would contains orders details.

<pre class="headers"><code>Sample: Event Message</code></pre>
<%= json :event %>

The Spree Professional platform ensures each event is received and processed successfully by your integration endpoint, by waiting for a response which must contain the following fields:

* _event_id_ - The unique id for the message that is being processed.
* _result_ - A string representing the outcome, acceptable values: 'ok', 'fail', 'delay'.
* _details_ - Any optional relevant information regarding the processing of the event.

<pre class="headers"><code>Sample: Message Response</code></pre>
<%= json :event_response %>
