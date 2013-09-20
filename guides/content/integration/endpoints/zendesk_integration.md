---
title: Zendesk Endpoint
---

## Overview

[Zendesk](http://www.zendesk.com/) offers a customer service software platform. Integration with Zendesk allows you to create and process help desk tickets in support of your customer base.

+++
The source code for the [Zendesk Endpoint](https://github.com/spree/zendesk_endpoint/) is available on Github.
+++

## Services

### Import

Imports a notification message of type "notification:error" or "notification:warning" and creates a Zendesk ticket for it.

#### Request

---notification:error---
```json
{
  "message": "notification:error",
  "message_id": "518726r84910515003",
  "payload": {
    "subject": "Product not in stock.",
    "description": "Attempted to order a product that wasn't in stock."
  }
}
```

---notification:warning---
```json
{
  "message": "notification:warning",
  "message_id": "518726r84910515103",
  "payload": {
    "subject": "Shipment was delayed.",
    "description": "Shipment for order R123456789 was delayed due to weather."
  }
}
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| zendesk.url | Your Zendesk Domain | https://mywidgets.zendesk.com/api/v2/ |
| zendesk.username | Your Zendesk Username/Email | mywidgets@example.com |
| zendesk.password | Your Zendesk Login Password | password |
| zendesk.requester_name | Name to use for the ticket's Requester | Joe Jackson |
| zendesk.requester_email | Email to use for the ticket's Requester | joe_jackson@example.com |
| zendesk.warning_priority | The Zendesk priority to assign to warning notificiations. Values are "urgent", "high", "normal", or "low". Default is "high" | high |
| zendesk.error_priority | The Zendesk priority to assign to error notificiations. Values are "urgent", "high", "normal", or "low". Default is "urgent" | urgent |

#### Response

```json
{
  "message_id": "518726r84910515003",
  "notifications": [
    "level": "info",
    "subject": "Help ticket created",
    "description": "New Zendesk ticket number 12 created, priority: high."
  ]
}
```
