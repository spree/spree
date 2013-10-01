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