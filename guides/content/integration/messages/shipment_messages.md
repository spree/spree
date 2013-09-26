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
  "message": "shipment:ready",
  "payload": {
    "shipment": {
      "number": "H11357178202",
      "order_number": "R543221177",
      "email": "spree@example.com",
      "cost": 1.95,
      "status": "ready",
      "stock_location": null,
      "shipping_method": "Standard Shipping",
      "tracking": null,
      "updated_at": null,
      "shipped_at": null,
      "shipping_address": {
        "firstname": "John",
        "lastname": "Do",
        "address1": "Street 134",
        "address2": "",
        "zipcode": "1234AB",
        "city": "Somewhere",
        "state": "Friesland",
        "country": "NL",
        "phone": "06123456753"
      },
      "items": [
        {
          "name": "Ruby on Rails Tote",
          "sku": "ROR-00011",
          "external_ref": "",
          "quantity": 1,
          "price": 15.99,
          "variant_id": 1,
          "options": {
            
          }
        }
      ]
    },
    "order": { ... },
    "original": { ... }
  }
}
```

### shipment:confirm

This type of Message is sent whenever an order shipment is confirmed and sent. It includes the tracking information so the customer can use it to track his/her order.

---shipment_confirm.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "shipment:confirm",
  "payload": {
    "shipment": {
      "number": "H11357178202",
      "order_number": "R543221177",
      "email": "spree@example.com",
      "cost": 1.95,
      "status": "shipped",
      "stock_location": null,
      "shipping_method": "Standard Shipping",
      "tracking": "tracking-1234-ABC",
      "updated_at": null,
      "shipped_at": "2013-09-26T10:21:52Z",
      "shipping_address": {
        "firstname": "John",
        "lastname": "Do",
        "address1": "Street 134",
        "address2": "",
        "zipcode": "1234AB",
        "city": "Somewhere",
        "state": "Friesland",
        "country": "NL",
        "phone": "06123456753"
      },
      "items": [
        {
          "name": "Ruby on Rails Tote",
          "sku": "ROR-00011",
          "external_ref": "",
          "quantity": 1,
          "price": 15.99,
          "variant_id": 1,
          "options": {            
          }
        }
      ]
    }
  }
}
```

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
      "status": "ready",
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
          "quantity": 1,
          "price": 19.99,
          "options": {"color": "BLK", "size": "XL" }
        },
        {
          "name": "Foo Shoe",
          "sku": "DEF-123",
          "external_ref": "DDD-123",
          "quantity": 3,
          "price": 23.99,
          "options": {"color": "BLK", "size": "XL" }
        }
      ]
    },
    "order": {
      ...
    }
  }
}
```