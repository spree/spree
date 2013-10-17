---
title: Sample Messages
---

## Overview

Sample messages can be generated using the Spree Commerce hub API. This guide walks through the types of sample messages available and how to generate them.

### Available Sample Messages

To get a list of the available sample messages, make the following request:

```text
GET http://hub.spreecommerce.com/api/samples```

You will get a response that contains a JSON array of the available messages you can generate samples for.

---available sample messages---
```json
[
  "order:persist",
  "order:new",
  "order:update",
  "order:cancel",
  "shipment:ready",
  "payment:capture",
  "stock:change"
]```

### Generating A Sample Message

To generate a sample message, append the message name to the URL used to get the list of available messages. For example, to generate an `order:new` message, make the following request:

```text
GET http://hub.spreecommerce.com/api/samples/order:new```

The response will be a JSON representation of the message that looks similar to the following:

---order:new sample---
```json
{
  "message":"order:new",
  "payload":{
    "order":{
      "number":"R633547138",
      "channel":"spree",
      "email":"spree@example.com",
      "currency":"USD",
      "placed_on":"2013-07-30T19:19:05Z",
      "updated_at":"2013-07-30T20:08:39Z",
      "status":"complete",
      .....
    }
  }
}```

To generate a sample message for a specific Spree version specify `version` as a query string parameter. For example, to generate an `order:persist` message for Spree 2.0, make the following request:

```text
GET http://hub.spreecommerce.com/api/samples/order:persist?version=2.0```

***
Note that most messages are Spree version independent, but some are not such as `*:persist` messages.
***
