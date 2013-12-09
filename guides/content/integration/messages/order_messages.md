---
title: Order Messages
---

## Overview

## Message Types

### order:new

When a new order is created, this is the message that will be send out. The ```original``` is the Spree::Order, while the ```order``` is the generic Integrator order format.

---order_new.json---
```json
{
  "message": "order:new",
  "payload": {
    "order": {
      "number": "R104702249",
      "channel": "spree",
      "email": "spree@example.com",
      "currency": "USD",
      "placed_on": "2013-07-30T19:19:05Z",
      "updated_at": "2013-07-30T20:08:39Z",
      "status": "complete",
      "totals": {
        "item": 99.95,
        "adjustment": 15,
        "tax": 5,
        "shipping": 0,
        "payment": 114.95,
        "order": 114.95
      },
      "line_items": [
        {
          "name": "Spree Baseball Jersey",
          "sku": "SPR-00001",
          "external_ref": "",
          "quantity": 2,
          "price": 19.99,
          "variant_id": 8,
          "options": {
            
          }
        },
        {
          "name": "Ruby on Rails Baseball Jersey",
          "sku": "ROR-00004",
          "external_ref": "",
          "quantity": 3,
          "price": 19.99,
          "variant_id": 20,
          "options": {
            "tshirt-color": "Red",
            "tshirt-size": "Medium"
          }
        }
      ],
      "adjustments": [
        {
          "name": "Shipping",
          "value": 5
        },
        {
          "name": "Shipping",
          "value": 5
        },
        {
          "name": "North America 5.0%",
          "value": 5
        }
      ],
      "shipping_address": {
        "firstname": "Brian",
        "lastname": "Quinn",
        "address1": "7735 Old Georgetown Rd",
        "address2": "",
        "zipcode": "20814",
        "city": "Bethesda",
        "state": "Maryland",
        "country": "US",
        "phone": "555-123-456"
      },
      "billing_address": {
        "firstname": "Brian",
        "lastname": "Quinn",
        "address1": "7735 Old Georgetown Rd",
        "address2": "",
        "zipcode": "20814",
        "city": "Bethesda",
        "state": "Maryland",
        "country": "US",
        "phone": "555-123-456"
      },
      "payments": [
        {
          "number": 6,
          "status": "completed",
          "amount": 5,
          "payment_method": "Check"
        },
        {
          "number": 5,
          "status": "completed",
          "amount": 109.95,
          "payment_method": "Credit Card"
        }
      ],
      "shipments": [
        {
          "number": "H286178199",
          "cost": 5,
          "status": "shipped",
          "stock_location": null,
          "shipping_method": "UPS Ground (USD)",
          "tracking": null,
          "updated_at": null,
          "shipped_at": "2013-07-30T20:08:38Z",
          "items": [
            {
              "name": "Spree Baseball Jersey",
              "sku": "SPR-00001",
              "external_ref": "",
              "quantity": 1,
              "price": 19.99,
              "variant_id": 8,
              "options": {
                
              }
            },
            {
              "name": "Ruby on Rails Baseball Jersey",
              "sku": "ROR-00004",
              "external_ref": "",
              "quantity": 1,
              "price": 19.99,
              "variant_id": 20,
              "options": {
                "tshirt-color": "Red",
                "tshirt-size": "Medium"
              }
            }
          ]
        },
        {
          "number": "H803900939",
          "cost": 5,
          "status": "ready",
          "stock_location": null,
          "shipping_method": "UPS Ground (USD)",
          "tracking": "4532535354353452",
          "updated_at": null,
          "shipped_at": null,
          "items": [
            {
              "name": "Ruby on Rails Baseball Jersey",
              "sku": "ROR-00004",
              "external_ref": "",
              "quantity": 2,
              "price": 19.99,
              "variant_id": 20,
              "options": {
                "tshirt-color": "Red",
                "tshirt-size": "Medium"
              }
            },
            {
              "name": "Spree Baseball Jersey",
              "sku": "SPR-00001",
              "external_ref": "",
              "quantity": 1,
              "price": 19.99,
              "variant_id": 8,
              "options": {
                
              }
            }
          ]
        }
      ]
    },
    "original": {
      "id": 5,
      "number": "R104702249",
      "item_total": "99.95",
      "total": "114.95",
      "state": "complete",
      "adjustment_total": "15.0",
      "user_id": 1,
      "created_at": "2013-07-29T17:42:02Z",
      "updated_at": "2013-07-30T20:08:39Z",
      "completed_at": "2013-07-30T19:19:05Z",
      "payment_total": "114.95",
      "shipment_state": "partial",
      "payment_state": "paid",
      "email": "spree@example.com",
      "special_instructions": null,
    }
  }
}
```

### order:updated

When an order is updated, the following message will be send out. The ```order``` and ```previous``` are all in the generic Integrator format, while the ```original``` is the ```Spree::Order```. The ```diff`` key contains all the changes that happend for this order.

---order_updated.json---
```json
{
  "message": "order:updated",
  "payload": {
    "order": { ... },
    "original": { ... },
    "previous": { ... },
    "diff": {
      "updated_at": [
        "2013-09-25T09:36:39Z",
        "2013-09-25T13:06:18Z"
      ],
      "payments": [
        [
          {
            "id": 2,
            "amount": "24.14",
            "state": "pending",
            "payment_method_id": 1,
            "payment_method": {
              "id": 1,
              "name": "Credit Card",
              "environment": "development"
            }
          }
        ],
        [
          {
            "id": 2,
            "amount": "24.14",
            "state": "void",
            "payment_method_id": 1,
            "payment_method": {
              "id": 1,
              "name": "Credit Card",
              "environment": "development"
            }
          }
        ]
      ]
    }
  }
}
```

### order:canceled

The only difference with this messages that is send out is the status, this will be ```canceled```

---order_canceled.json---
```json
{
  "message": "order:canceled",
  "payload": {
  "order": {
    ...
    "status": "canceled",
  },
  "original": { ... }
}
```
