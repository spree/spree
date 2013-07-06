---
title: Notification Messages
---

## Overview

Notification Messages are generally used by Endpoints to convey information to the owner of the store (or one of their employees.) These Messages are typically generated in the context of an Endpoint Service Request and should always be sent with a HTTP Status Code of `200`.

***
Notification Messages can be mapped to Endpoints just like any other Message. By default they are also automatically converted into Log Entries.
***

## Message Types

### Info

This Message type is for communicating interesting information from Endpoint Services. It is common for this type of Message to be sent in response after an Endpoint processes an inbound Message.

<pre class="headers"><code>notification:info</code></pre>
```json
{
  "message": "notification:info",
  "message_id": "518726r84910000001",
  "payload": {
    "subject": "Tracking number assigned",
    "description": "Shipment has been given a tracking #123443-5242."
  }
}```

### Warn

Use this Message type to indicate that a Service executed successfully but that there may be a potential problem that's worth investigating.

<pre class="headers"><code>notification:warn</code></pre>
```json
{
  "message": "notification:warn",
  "message_id": "518726r84910000002",
  "payload": {
    "subject": "Unable to verify address",
    "description": "Shipment #H123456 contains an address that was unabled to be verified. We have shipped the package anyways but it may not get there!"
  }
}```

### Error

Use this Message type to indicate that a Service was unable to perform the requested action. Typically this is a validation problem with the service or some other type of permanent failure. For example, a shipment is being requested to a country that is not eligible for shipping by the carrier. Use `notification:error` messages when no amount of retrying will change the outcome and its time to notify someone in charge of troubleshooting problems with the store.

!!!
Do not use this message for exceptional situations such as the inability to connect to a third party server. Those types of exceptions are considered [Failures](TODO) and should be handled by returning a `5XX` error code instead.
!!!

<pre class="headers"><code>notification:error</code></pre>
```json
{
  "message": "notification:error",
  "message_id": "518726r84910000003",
  "payload": {
    "subject": "Shipment rejected",
    "description": "We are unable to ship overnight packages to Afghanistan."
  }
}```

### New Order

Use this type of Message whenever a new order is created.

<pre class="headers"><code>order:new</code></pre>
```json
{
  "message": "order:new",
  "message_id": "518726r84910000004",
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

### Updated Order

This type of Message should be sent when an existing order is updated.

<pre class="headers"><code>order:new</code></pre>
```json
{
  "message": "order:updated",
  "message_id": "518726r84910000004",
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

### Canceled Order

You should send this type of Message whenever an order is canceled, whether by the customer or by a store administrator.

<pre class="headers"><code>order:new</code></pre>
```json
{
  "message": "order:canceled",
  "message_id": "518726r84910000004",
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

### Confirmed Shipment

This type of Message is sent whenever an order shipment is confirmed and sent. It includes the tracking information so the customer can use it to track his/her order.

TODO: confirm the tracking url and carrier values supplied.

<pre class="headers"><code>order:new</code></pre>
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
    "TODO": "line_items and items and orders, oh my! What else goes here?"
  }
}```

### Retrieve New Amazon Orders

This message is used for you to poll the Amazon API, retrieve any new orders you have for your seller account, and import them into your Spree store.

```json
{
  "message": "amazon:order:poll",
  "message_id": "1234567"
}```