---
title: Tender Endpoint
---

## Overview

[Tender](http://www.tenderapp.com/) offers a customer service software platform. Integration with Tender allows you to create and process support discussions in support of your customer base.

+++
The source code for the [Tender Endpoint](https://github.com/spree/tender_endpoint/) is available on Github.
+++

## Services

### Import

Imports a notification message of type "notification:error" or "notification:warning" and creates a Tender discussion for it.

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
| tender.domain | Your Tender Domain | mywidgets |
| tender.api_key | Your Tender API Key | 1234567890 |
| tender.author_name | The name that will be used when creating new discussions  | Joe Jackson |
| tender.author_email | The email that will be used when creating new discussions |  joe_jackson@example.com |
| tender.category_id | The ID of the category the discussion should be created under | 777 |
| tender.public | Should newly created discussions be public? Must be either true or false | true |

#### Response

```json
{
  "message_id": "518726r84910515003",
  "notifications": [
    "level": "info",
    "subject": "TenderApp Discussion Created",
    "description": "New TenderApp discussion 'Something went wrong' created at https://mywidgets.tenderapp.com/discussions/questions/4."
  ]
}
```
