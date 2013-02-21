---
title: Spree Professional Events
---

# Consuming Events

Events can be created in two locations:

1. Within a Spree store as users complete actions like: customers signing up, completing checkouts, administrators processing orders or uploading new products.
2. Externally inside other systems, which then transmit those events to Spree Professional for processing. For more see “Pushing Events”.

All events can be consumed by your integration endpoint, with each individual event resulting in a JSON encoded message being dispatched via HTTP to a pre-configured endpoint URL.

Using the Spree Professional control panel you can configure a list of the events you want to subscribe to, and a list of corresponding endpoint URLs that will process those events.

## Available Events

Spree Professional currently supports the following events:


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
