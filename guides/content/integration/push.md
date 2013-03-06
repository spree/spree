---
title: Spree Pro Integration Guide - Pushing Events
---

# Pushing Events

Applications can push new events to Spree Professional. These can be triggered when an order has changed, a shipment has shipped, a payment has been captured or a new user has signed up.

## Overview

Applications can be notified when events occur in Spree Professional and can push events back to Spree Professional. This creates a bidirectional conversation between Spree Professional and integrated services.

The Spree Professional Event API allows your application to have a single endpoint for notifications. Since Spree Professional has already been integrated into many 3rd party services, your events can be routed without any additional work.

Spree professional accepts a standard description of orders and products. It will convert the descriptions into the format understood by each 3rd party service. You notify Spree Professional, we'll take care of the rest.

Events can be pushed to Spree Professional by POSTing JSON documents to new events url:

    http://integrator.spreecommerce.com/events

The posted events will be queued up for processing. The response will include an event ID. Events that can be posted include:

* _New Order_ - after a successful checkout has been completed.
* _Updated Order_ - any event that changes a completed order, for example: adding new products, changing shipments, etc.
* _Canceled Order_ - after a completed order has been canceled.
* _Payment Ready_ - when an authorized payment is deemed ready for capturing.
* _Shipment Ready_ - when a shipment is considered ready to ship.
* _Shipment Confirmation_ - after a shipment has been classified as dispatched.
* _New Product_ - when a new product has been added to a store.
* _Updated Product_ - any event that changes a product, for example: updating stock levels, descriptions, artwork etc.
* _New User_ - after a new customer sign up
* _Updated User_ - after a customer updates their personal details (email, shipping address, etc).

## Updating a shipment

If your integration was responsible for processing shipments, it may want to update the Spree store (and other systems) that it had just dispatched a shipment. In this case you could push a "Shipment Confirmation" message that would in turn update the Spree stores shipment record, and any other external systems that were subcribed to that event.

### Pusing a Shipment Confirmation event
When the shipment had disptached you can use an HTTP post to send the event to Spree Professional.

    POST http://integrator.spreecommerce.com/events

<pre class="headers"><code>Sample: Shipment Confirmation Push</code></pre>
<%= json :push_shipment_confirmation %>

response will be:

<pre class="headers"><code>Sample: Shipment Confirmation Response</code></pre>
<%= json :push_shipment_response %>

Spree Professional when then route this message to the Spree store for processing, and any other consumers that are registered for that event.

### New Product

If your integration was responsible for managing products, it may want to add new products to the Spree store (and other systems) when they have been marked for sale. In this instance you would push a "New Product" message that would create the product within the Spree store and notify any other external systems that were subscribed to that event.

    POST http://integrator.spreecommerce.com/events

<pre class="headers"><code>Sample: New Product Push</code></pre>
<%= json :new_product_push %>

response will be:

<pre class="headers"><code>Sample: New Product Response</code></pre>
<%= json :new_product_push_response %>

Spree Professional when then route this message to the Spree store for processing, and any other consumers that are registered for that event.

