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

---notification:info---
```json
{
  "message": "notification:info",
  "message_id": "518726r84910000001",
  "source": "incoming",
  "payload": {
    "subject": "Tracking number assigned",
    "description": "Shipment has been given a tracking #123443-5242."
  }
}
```

### Warn

Use this Message type to indicate that a Service executed successfully but that there may be a potential problem that's worth investigating.

---notification:warn---
```json
{
  "message": "notification:warn",
  "message_id": "518726r84910000002",
  "source": "mandrill.order_confirmation",
  "payload": {
    "subject": "Unable to verify address",
    "description": "Shipment #H123456 contains an address that was unabled to be verified. We have shipped the package anyways but it may not get there!"
  }
}
```

### Error

Use this Message type to indicate that a Service was unable to perform the requested action. Typically this is a validation problem with the service or some other type of permanent failure. For example, a shipment is being requested to a country that is not eligible for shipping by the carrier. Use `notification:error` messages when no amount of retrying will change the outcome and its time to notify someone in charge of troubleshooting problems with the store.

!!!
Do not use this message for exceptional situations such as the inability to connect to a third party server. Those types of exceptions are considered [Failures]() and should be handled by returning a `5XX` error code instead.
!!!

$$$
Fix the link above
$$$

---notification:error---
```json
{
  "message": "notification:error",
  "message_id": "518726r84910000003",
  "source": "spree.order_poller"
  "payload": {
    "subject": "Shipment rejected",
    "description": "We are unable to ship overnight packages to Afghanistan."
  }
}
```