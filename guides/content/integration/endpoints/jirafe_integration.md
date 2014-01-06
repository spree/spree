---
title: Jirafe Endpoint
---

## Overview

[Jirafe](http://jirafe.com) is an ecommerce analytics service that gives you 
quick access to marketing, merchandising, and transaction data.

+++
The source code for the [Jirafe 
Endpoint](https://github.com/spree/jirafe_endpoint/) is available on Github.
+++

## Services

### Import Carts

Send shopping cart data to Jirafe.

#### Request

### cart:new, cart:updated

---import_cart.json---
```json
{
  "message": "cart:new",
  "payload": {
    "cart": {
      ...
    }
  }
}
```

#### Response

---notifications_info.json---

```json
{
  "notifications": [
    {
      "level": "info",
      "subject": "Cart event sent to Jirafe",
      "description": "A cart event for R827035050 was sent to Jirafe."
    }
  ]
}
```

---notifications_error.json---

```json
{
  "notifications": [
    {
      "level": "error",
      "subject": "There was a problem while sending a cart event to Jirafe.",
      "description": "..."
    }
  ]
}
```

#### Parameters

| Name | Value | Data Type | Required? |Example |
| :----| :-----| :------ |:------ | :------ |
| jirafe.site_id | Your Jirafe Site ID | string | Yes | 1234567890 |
| jirafe.access_token | Your Jirafe OAuth Access Token | string | Yes | dj20492dhjkdj20492dhjk |

### Import Orders

Send new and updated order data to Jirafe. Also sends the latest shopping cart information 
available for that order.

#### Request

### order:new, order:updated

---new_order.json---
```json
{
  "message": "order:new",
  "payload": {
    "order": {
      ...
    }
  }
}
```

#### Response

---notifications_info.json---

```json
{
  "notifications": [
    {
      "level": "info",
      "subject": "Cart event sent to Jirafe",
      "description": "A cart event for R827035050 was sent to Jirafe."
    },
    {
      "level": "info",
      "subject": "Order placed event sent to Jirafe",
      "description": "An order-placed event for R827035050 was sent to Jirafe."
    },
    {
      "level": "info",
      "subject": "Order accepted event sent to Jirafe",
      "description": "An order-accepted event for R827035050 was sent to Jirafe."
    }
  ]
}
```

---notifications_error.json---

```json
{
  "notifications": [
    {
      "level": "error",
      "subject": "There was a problem while sending an order-accepted event to Jirafe.",
      "description": "..."
    }
  ]
}
```

#### Parameters

| Name | Value | Data Type | Required? |Example |
| :----| :-----| :------ |:------ | :------ |
| jirafe.site_id | Your Jirafe Site ID | string | Yes | 1234567890 |
| jirafe.access_token | Your Jirafe OAuth Access Token | string | Yes | dj20492dhjkdj20492dhjk |
| jirafe.store_url | Your Store's URL | string | Yes | dj20492dhjkdj20492dhjk |
| jirafe.product_category_taxonomy | The ID of the parent taxonomy whose taxons you want synced | string | Yes | 2 |
| jirafe.brand_category_taxonomy | The ID of the Taxonomy that contains your Brand taxons | string | Yes | 4 |
