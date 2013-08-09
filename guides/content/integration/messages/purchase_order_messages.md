---
title: Order Messages
---

## Overview

## Message Types

### purchase_order:new

Use this type of Message whenever a new order is created.

---purchase_order_new.json---
```json
{
  "message": "purchase_order:new",
  "payload": {
    "purchase_order": {
       "po_number": "12345",
       "order_date": "2009-09-01T00:00:00Z",
       "carrier": "UPS",
       "service_level": "ground",
       "primary_tracking_id": "1234",
       "order_type": "SELL_FIRST",
       "alt_po_number": "6789",
       "warehouse": "ALL",
       "vendor": {
         "id": "12345",
         "company": "Spree",
         "contact": "Jon Doe",
         "address1": "5555 Test Lane",
         "address2": "",
         "address3": "",
         "city": "SomeCity",
         "state": "Md",
         "postal_code": "20837",
         "country": "US",
         "phone": "555-555-5555",
         "fax": "",
         "email": "test@test.com"
       },
       "line_items": [
         { "line_item": {
             "item_number": "123456",
             "order_quantity": 1,
             "item_description": "this is an item",
             "unit_cost": "5.00",
             "unit_weight": "8lbs",
             "unit_pack_quantity": 1,
             "catron_id": "123"
            }
          }
        ]
      }
    }
  }```

### purchase_order:received
Use this message to mark a purchase order as received

---purchase_order_received.json---
```json
{
  "message": "purchase_order:received",
  "payload": {
    "purchase_order": {
      "po_number": "123456",
      "items": [
        {
          "line": "1",
          "item_number": "334392",
          "quantity": "64",
          "date": "2012-08-22T20:25:45.2706497Z"
        },
        {
          "line": "2",
          "item_number": "334393",
          "quantity": "27",
          "date": "2012-08-22T20:25:45.286285Z"
        }
      ]
    }
  }
}
```

### purchase_order:confirm
Use this message to mark a purchase order as confirmed

---purchase_order_confirm.json---
```json
{
  "message": "purchase_order:confirm",
  "payload": {
    "purchase_order": {
      "po_number": "123456"
    }
  }
}
```