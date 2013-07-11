---
title: Order Messages
---

## Overview

## Message Types

### New Order

Use this type of Message whenever a new order is created.

---order:new---
```json
{
  "message": "order:new",
  "payload": {
    "order": {
      "channel": "Amazon",
      "email": "test1@test.com",
      "currency": "USD",
      "line_items": [
        {
          "price": 19.99,
          "sku": "ABC-123",
          "name": "Foo T-Shirt Size(L)",
          "quantity": 1
        },
        {
          "price": 23.99,
          "sku": "DEF-123",
          "name": "Foo Socks",
          "quantity": 3
        }
      ],
      "shipping_address": {
        "firstname": "Chris",
        "lastname": "Mar",
        "address1": "112 Hula Lane",
        "address2": "",
        "city": "Leesburg",
        "zipcode": "20175",
        "phone": "555-555-1212",
        "company": "RubyLoco",
        "country": "US",  
        "state": "Virginia"
      },
      "billing_address": {
        "firstname": "Chris",
        "lastname": "Mar",
        "address1": "112 Billing Lane",
        "address2": "",
        "city": "Leesburg",
        "zipcode": "20175",
        "phone": "555-555-1212",
        "company": "RubyLoco",
        "country": "US",  
        "state": "Viriginia"
      },
      "adjustments":[
        { "name": "Shipping Discount", "value": "-4.99" },
        { "name": "Promotion Discount", "value": "-3.00" }
      ],
      "shipments": [
        {
          "cost": 29.99,
          "stock_location": "PCH",
          "shipping_method": "UPS Next Day",
          "items": [
              {
                "sku": "ABC-123",
                "quantity": 1
              },
              {
                "sku": "DEF-123",
                "quantity": 3
              }
            ]
          }
        }
      ]
    }
  }
}```

### Updated Order

This type of Message should be sent when an existing order is updated.

---order:cancel---
```json
{
  "message": "order:cancel",
  "message_id": "518726r84910000004",
  "payload": {
    "order": {
      "actual": {
        "number": "R186559068",
        "ship_address": {
          "firstname": "John",
          "lastname": "Doe",
          "company": "ABC Widgets",
          "address1": "123 Main St.",
          "address2": "",
          "city": "Ambrosio",
          "state_id": 123,
          "country": {
            "iso": "US"
          },
          "zipcode": "25501"
        },
        "bill_address": {
          "firstname": "Jane",
          "lastname": "Doe",
          "company": "ABC Widgets",
          "address1": "456 Oak Ave.",
          "address2": "",
          "city": "Ambrosio",
          "state_id": 123,
          "country": {
            "iso": "US"
          },
          "zipcode": "25501"
        },
        "item_total": "25.0",
        "total": "23.0",
        "shipment_state": "ready",
        "line_items": [
          {
            "quantity": 5,
            "price": "5.0",
            "variant": {
              "name": "Wiggly Worm Widget"
            }
          }
        ],
      },
      "original": {
        ...
      }
    }
  }
}```

### Canceled Order

You should send this type of Message whenever an order is canceled, whether by the customer or by a store administrator.

---order:cancel---
```json
{
  "message": "order:cancel",
  "message_id": "518726r84910000004",
  "payload": {
    "order": {
      "actual": {
        "number": "R186559068",
        "ship_address": {
          "firstname": "John",
          "lastname": "Doe",
          "company": "ABC Widgets",
          "address1": "123 Main St.",
          "address2": "",
          "city": "Ambrosio",
          "state_id": 123,
          "country": {
            "iso": "US"
          },
          "zipcode": "25501"
        },
        "bill_address": {
          "firstname": "Jane",
          "lastname": "Doe",
          "company": "ABC Widgets",
          "address1": "456 Oak Ave.",
          "address2": "",
          "city": "Ambrosio",
          "state_id": 123,
          "country": {
            "iso": "US"
          },
          "zipcode": "25501"
        },
        "item_total": "25.0",
        "total": "23.0",
        "shipment_state": "ready",
        "line_items": [
          {
            "quantity": 5,
            "price": "5.0",
            "variant": {
              "name": "Wiggly Worm Widget"
            }
          }
        ],
      },
      "original": {
        ...
      }
    }
  }
}```
