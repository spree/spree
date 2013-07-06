---
title: Mandrill Endpoint
---

## Overview

[Mandrill](http://mandrill.com/) is a transactional email platform that you can use to automatically process your store's emails through the Spree Integrator. Mandrill could be called on any time you needed to, for example:

* confirm to a user that you have received their order,
* notify a user that their order was canceled, or
* send shipment confirmation to a customer.

## Requirements

In order to configure and use the [mandrill_endpoint](https://github.com/spree/mandrill_endpoint), you will need to first have:

* an account on Mandrill,
* an API token from that account, and
* templates set up in your Mandrill account

## Services

***
To see thorough detail on how a particular JSON Message should be formatted, check out the [Notification Messages guide](notification_messages).
***

### Order Confirmation

TODO: The trigger language here is sloppy. Presume it's when an order reaches a particular state(s).
This Service should be triggered any time a new order is created, or when an existing order is updated. When the Endpoint receives a validly-formatted Message to the `/order_confirmation` URL, it passes the order's information on to Mandrill's API. Mandrill then sends an email to the user using its matching stored [template](#template), confirming that their order was received.

<pre class="headers"><code>A new order is created</code></pre>
```json
{
  "message": "order:new",
  "payload": {
    "order": {
      ...
    }
  }
}```

<pre class="headers"><code>An order is updated</code></pre>
```json
{
  "message": "order:updated",
  "payload": {
    "order": {
      ...
    }
  }
}```

### Order Cancellation

TODO: Is this the correct scenario?
If a user or an admin cancels an existing order, the store should send a JSON message with the relevant data to the `/order_cancellation` URL. The Endpoint will transmit a Message to Mandrill, which then sends an email to the user, confirming that the order was canceled.

```json
{
  "message": "order:canceled",
  "payload": {
    "order": {
      ...
    }
  }
}```

### Shipment Confirmation

After an order moves to the `shipped` order state, the store should send notice via the Integrator to theEndpoint's `/shipment_confirmation` URL, with the relevant order and shipment data. The Endpoint will then instruct Mandrill to email the customer, notifying them that the order is en route.

```json
{
  "message": "shipment:confirmation",
  "message_id": "518726r84910000004",
  "payload": {
    "shipment_number": 1,
    "tracking_number": "71N4i304",
    "tracking_url": "http://www.ups.com/WebTracking/track",
    "carrier": "UPS",
    "shipped_date": "2013-06-27T13:29:46Z",
    ...
  }
}```

TODO: Supply whatever substitutes for the "..." above

## Configuration

TODO: Elaborate when we finalize the connector.

### Name

### Keys

#### api_key

#### from

#### subject

#### template

### Parameters

### Url

### Token

### Event Keys

### Event Details

### Filters

### Retries