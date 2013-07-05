---
title: Mandrill Endpoint
---

## Overview

[Mandrill](http://mandrill.com/) is a transactional email platform that you can use to automatically process your store's emails through the Spree Integrator. Mandrill could be called on any time you needed to, for example:

* confirm to a user that you have received their order,
* notify a user that their order was canceled, or
* send shipment confirmation to a customer.

## Requirements

In order to configure and use the mandrill_endpoint, you will need to first have:

* an account on Mandrill,
* an API token from that account, and
* templates set up in your Mandrill account

## Services

There are message types that the mandrill_endpoint can respond to (incoming), and those that it can, in turn, generate (outgoing). A Service Request is the sequence of actions the endpoint takes when the Integrator sends it a Message. There are several types of Service Requests you can make to the mandrill_endpoint. Each is listed below, along with one or more sample JSON Messages like the ones you would send.

### Order Confirmation

TODO: The trigger language here is sloppy. Presume it's when an order reaches a particular state(s).
This Service should be triggered any time a new order is created, or when an existing order is updated. When the `mandrill_endpoint` receives a validly-formatted Message to the `/order_confirmation` URL, it passes the order information on to Mandrill's API. Mandrill then sends an email using its matching stored [template](#template) to the user, confirming that their order was received.

<pre class="headers"><code>A new order is created</code></pre>

```json
{
  "message": "order:new",
  "payload": {
    "order": {
      "actual": {
        "number": "R186559068",
        "ship_address": {
          "firstname": "John",
          "lastname": "Doe",
          "company": "ABC Widgets",
          "address1": "123 Main St.",
          "address2": "",
          "city": "Ambrosio",
          "state_id": 123,
          "country": {
            "iso": "US"
          },
          "zipcode": "25501"
        },
        "bill_address": {
          "firstname": "Jane",
          "lastname": "Doe",
          "company": "ABC Widgets",
          "address1": "456 Oak Ave.",
          "address2": "",
          "city": "Ambrosio",
          "state_id": 123,
          "country": {
            "iso": "US"
          },
          "zipcode": "25501"
        },
        "item_total": "25.0",
        "total": "23.0",
        "shipment_state": "ready",
        "line_items": [
          {
            "quantity": 5,
            "price": "5.0",
            "variant": {
              "name": "Wiggly Worm Widget"
            }
          }
        ],
      },
      "original": {
        ...
      }
    }
  }
}```

### Order Cancellation

TODO: Is this the correct scenario?
If a user or an admin cancels an existing order, the store should send a JSON message with the relevant data to the `/order_cancellation` URL. The end point will transmit a message to Mandrill, which then sends an email to the user, confirming that the order was canceled.

### Shipment Confirmation

After an order moves to the `shipped` order state, the store should send notice to the mandrill_endpoint's, via the integration's `/shipment_confirmation` URL, with the relevant order and shipment data. The endpoint will then instruct Mandrill to email the customer, notifying them that the order is en route.

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