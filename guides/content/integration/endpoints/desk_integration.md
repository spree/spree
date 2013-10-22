---
title: Desk Endpoint
---

## Overview

[Desk](http://www.desk.com/) offers a customer service software platform. Integration with Desk allows you to create and process help desk cases in support of your customer base.

+++
The source code for the [Desk Endpoint](https://github.com/spree/desk_endpoint/) is available on Github.
+++

## Services

### Import

Imports a notification message of type "notification:error" or "notification:warning" and creates a Desk support case for it.

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
| desk.url | Your Desk Url | https://mywidgets.desk.com |
| desk.username | Your Desk Account Email | mywidgets@example.com |
| desk.password | Your Desk Account Password | password |
| desk.requester_name | Name that goes in the from field on the Desk case | Joe Jackson |
| desk.requester_email | Email that goes in the from field on the Desk case |  joe_jackson@example.com |
| desk.to_email | The email the new case will be forwarded to | joe_jackson@example.com |
| desk.customer_email | The email of the customer that case will be created for | example@website.com |

#### Response

```json
{
  "message_id": "518726r84910515003",
  "notifications": [
    "level": "info",
    "subject": "Case created",
    "description": "New Desk case 'Something went wrong' created, priority: 4."
  ]
}
```
