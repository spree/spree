---
title: Shipment Messages
---

## Overview

## Message Types

### New

### Update

### Confirmed Shipment

This type of Message is sent whenever an order shipment is confirmed and sent. It includes the tracking information so the customer can use it to track his/her order.

$$$
confirm the tracking url and carrier values supplied.
$$$

---order:new---
```json
{
  "message": "shipment:confirmation",
  "message_id": "518726r84910000004",
  "payload": {
    "shipment_number": 1,
    "tracking_number": "71N4i304",
    "tracking_url": "http://www.ups.com/WebTracking/track",
    "carrier": "UPS",
    "shipped_date": "2013-06-27T13:29:46Z"
  }
}```

$$$
Line_items, items, orders - the payload above is missing more stuff; not sure what
$$$

### Cancel
