---
title: Shipment Messages
---

## Overview

## Message Types

### shipment:ready

---shipment_ready.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "shipment:cancel",
  "payload": {
    "shipment": {
      "number": "H12345678901",
      "order_number": "R123456789",
      "email": "sales@spreecommerce.com",
      "stock_location": "VPD",
      "shipping_method": "USPS 6-10 days",
      "tracking_number": "",      
      "updated_at": "01/01/2013 12:34:22 UTC",
      "shipping_address": {
          "firstname": "Brian",
          "lastname": "Quinn",
          "address1": "123 Not A. Street",
          "address2": "",
          "city": "Niskayuna",
          "zipcode": "12309",
          "phone": "5183776284",
          "country": "US",
          "state": "New York"
      },
      "items": [
        {
          "name": "Foo T-Shirt Size(L)",
          "sku": "ABC-123",
          "external_ref": "ABD-123",
          "quantity": 1
        },
        {
          "name": "Foo Shoe",
          "sku": "DEF-123",
          "external_ref": "DDD-123",
          "quantity": 3
        }
      ]
    },
    "order": {}
  }
}```

### shipment:confirm

This type of Message is sent whenever an order shipment is confirmed and sent. It includes the tracking information so the customer can use it to track his/her order.

---shipment_confirm.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "shipment:confirm",
  "payload": {
    "shipment": {
      "number": "H12345678901",
      "order_number": "R123456789",
      "email": "sales@spreecommerce.com",
      "stock_location": "VPD",
      "shipping_method": "USPS 6-10 days",
      "tracking_number": "ABC123456DEF",
      "updated_at": "01/01/2013 12:34:22 UTC",
      "shipping_address": {
          "firstname": "Brian",
          "lastname": "Quinn",
          "address1": "123 Not A. Street",
          "address2": "",
          "city": "Niskayuna",
          "zipcode": "12309",
          "phone": "5183776284",
          "country": "US",
          "state": "New York"
      },
      "items": [
        {
          "name": "Foo T-Shirt Size(L)",
          "sku": "ABC-123",
          "external_ref": "ABD-123",
          "quantity": 1
        },
        {
          "name": "Foo Shoe",
          "sku": "DEF-123",
          "external_ref": "DDD-123",
          "quantity": 3
        }
      ]
    },
    "order": {}
  }
}```

### shipment:cancel

---shipment_cancel.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "shipment:cancel",
  "payload": {
    "shipment": {
      "number": "H12345678901",
      "order_number": "R123456789",
      "email": "sales@spreecommerce.com",
      "stock_location": "VPD",
      "shipping_method": "USPS 6-10 days",
      "tracking_number": "",
      "updated_at": "01/01/2013 12:34:22 UTC",
      "shipping_address": {
          "firstname": "Brian",
          "lastname": "Quinn",
          "address1": "123 Not A. Street",
          "address2": "",
          "city": "Niskayuna",
          "zipcode": "12309",
          "phone": "5183776284",
          "country": "US",
          "state": "New York"
      },
      "items": [
        {
          "name": "Foo T-Shirt Size(L)",
          "sku": "ABC-123",
          "external_ref": "ABD-123",
          "quantity": 1
        },
        {
          "name": "Foo Shoe",
          "sku": "DEF-123",
          "external_ref": "DDD-123",
          "quantity": 3
        }
      ]
    },
    "order": {}
  }
}```