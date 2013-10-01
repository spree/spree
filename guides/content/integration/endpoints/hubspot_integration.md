---
title: HubSpot Endpoint
---

## Overview

[HubSpot](http://www.hubspot.com/) is an inbound marketing software platform that helps you track the success of your company's marketing strategy, using a variety of tools. Integration with HubSpot enables automatic creation and/or updating of existing contacts, based on orders that are created, updated, or canceled in your Spree store.

+++
The source code for the [HubSpot Endpoint](https://github.com/spree/hubspot_endpoint/) is available on Github.
+++

## Services

### Contact Import

Processes incoming orders that are new, updated, or canceled and either creates or updates the HubSpot contact that matches billing address for the order. Mappings between fields are as follows:

| HubSpot Field Name | Spree Store Field Name |
| :----| :-----| :------ |
| initial_campaign* | Order.campaign (custom field) |
| initial_promotion* | Order.promotion (custom field) |
| account_creation_date* | Order.created_at |
| firstname | Order.bill_address.firstname |
| lastname | Order.bill_address.lastname |
| email | Order.email |
| phone | Order.bill_address.phone |
| address | Order.bill_address.address1 + Order.bill_address.address2 |
| city | Order.bill_address.city |
| state | Order.bill_address.state (.abbr or .name) |
| zip | Order.bill_address.zipcode |
| country | Order.bill_address.country.name |
| lifecyclestage | --- (always sets to "Customer") |
| mrt_campaign* | Order.campaign (custom field) |
| mrt_promotion* | Order.promotion (custom field) |
| mrt_date* | Order.completed_at |
| mrt_order_number* | Order.number |
| mrt_total_shipping* | Order.ship_total |
| mrt_total_tax* | Order.tax_total |
| mrt_total_adjustment* | Order.adjustment_total |
| mrt_total_revenue* | Order.total |
| total_order_shipping* | Order.ship_total |
| total_order_tax* | Order.tax_total |
| total_order_adjustment* | Order.adjustment_total |
| total_order_revenue* | Order.total |
| total_transactions | Order.count |

'*'' denotes non-standard HubSpot fields. Fields prepended with ```mrt_``` are most recent transaction amounts; those prepended with ```total_``` are cumulative amounts for the lifetime of the contact.

#### Request

---order_new.json---
```json
{
  "message": "order:new",
  "payload": {
    "parameters": [
      {
        "name": "access_token",
        "value": "eac97693-26be-11e3-9a20-856fcdde1271"
      },
      {
        "name": "refresh_token",
        "value": "eac6b772-26be-11e3-9a20-856fcdde1271"
      }
    ],
    "order": {
      "number": "R123456789",
      "channel": "Amazon",
      "email": "test1@test.com",
      "currency": "USD",
      "placed_on": "2013-09-20T16:24:22-04:00",
      "updated_at": "2013-09-20T16:24:22-04:00",
      "status": "complete",
      "totals": {
        "item": 12.99,
        "adjustment": 10,
        "tax": 6,
        "shipping": 4,
        "payment": 29.99,
        "order": 29.99
      },
      "adjustments": [
        {
          "name": "Shipping Discount",
          "value": "-4.99"
        },
        {
          "name": "Promotion Discount",
          "value": "-3.00"
        }
      ],
      "line_items": [
        {
          "name": "Foo T-Shirt Size(L)",
          "sku": "ABC-123",
          "external_ref": "ABD-123",
          "name": "Foo T-Shirt Size(L)",
          "quantity": 1,
          "price": 19.99,
          "options": {
            "color": "BLK", 
            "size": "XL" 
          }
        },
        {
          "name": "Foo Shoe",
          "sku": "DEF-123",
          "external_ref": "DDD-123",
          "name": "Foo Socks",
          "quantity": 3,
          "price": 23.99,
          "options": {
            "color": "BLK", 
            "size": "XL" 
          }
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
        "country": "US",
        "state": "Viriginia"
      },
      "payments": [
        {
          "number": 1234,
          "status": "completed",
          "amount": 29.99,
          "payment_method": "Standard"
        }
      ],
      "shipments": [
        {
          "number": "1234567",
          "cost": 29.99,
          "status": "ready",
          "stock_location": "PCH",
          "shipping_method": "UPS Next Day",
          "tracking": null,
          "updated_at": null,
          "shipped_at": null,
          "items": [
            {
              "name": "Foo T-Shirt Size(L)",
              "sku": "ABC-123",
              "external_ref": "ABD-123",
              "quantity": 1,
              "price": 19.99,              
              "variant_id": 123,
              "options": {
                "color": "BLK", 
                "size": "XL" 
              }
            },
            {
              "name": "Foo Socks",
              "sku": "DEF-123",
              "external_ref": "DDD-123",
              "quantity": 3,
              "price": 23.99, 
              "variant_id": 789,             
              "options": {
                "color": "BLK", 
                "size": "XL" 
              }
            }
          ]
        }
      ]
    },
    "original": {
      "id": 900000,
      "number": "R123456789",
      "promotion": "123",
      "campaign": "456",
      "item_total": "12.99",
      "total": "29.99",
      "state": "complete",
      "adjustment_total": "10.00",
      "user_id": 8567,
      "created_at": "2013-09-20T16:24:22-04:00",
      "updated_at": "2013-09-20T16:24:22-04:00",
      "completed_at": "2013-09-20T16:24:22-04:00",
      "payment_total": "29.99",
      "shipment_state": "ready",
      "payment_state": "paid",
      "email": "test1@test.com",
      "special_instructions": null,
      "currency": "USD",
      "ship_total": "4.00",
      "tax_total": "6.00",
      "bill_address": { 
        "firstname": "Chris",
        "lastname": "Mar",
        "address1": "112 Hula Lane",
        "address2": "",
        "city": "Leesburg",
        "zipcode": "20175",
        "phone": "555-555-1212",
        "country": {
          "name": "US"
        },
        "state": {
          "abbr": "VA",
          "name": "Virginia"
        }
      },
      "ship_address": { },
      "line_items": [ { } ],
      "payments": [ { } ],
      "shipments": [ { } ],
      "adjustments": [ { } ],
      "credit_cards": [ { } ],
      "store_id": { "$oid": "62n8eaa2b4381934bc000001" },
      "next_id": null,
      "_id": "123poi67q98712304658mq8r"
    }
  }
}
```

### order:updated

This type of Message should be sent when an existing order is updated.

---order_updated.json---
```json
{
  "message": "order:updated",
  "payload": {
    "parameters": [
      {
        "name": "access_token",
        "value": "eac97693-26be-11e3-9a20-856fcdde1271"
      },
      {
        
        "name": "refresh_token",
        "value": "eac6b772-26be-11e3-9a20-856fcdde1271"
      }
    ],
    "order": {
      "channel": "Amazon",
      "email": "test1@test.com",
      "currency": "USD",
      "placed_on": "01/01/2013 12:34:22 UTC",
      "updated_at": "01/01/2013 12:34:22 UTC",
      "status": "complete",
      "totals": {
        "item": 112.99,
        "adjustment": 10,
        "tax": 6,
        "shipping": 4,
        "order": 129.99
      },
      "adjustments": [
        {
          "name": "Shipping Discount",
          "value": "-4.99"
        },
        {
          "name": "Promotion Discount",
          "value": "-3.00"
        }
      ],
      "line_items": [
        {
          "name": "Foo T-Shirt Size(L)",
          "sku": "ABC-123",
          "external_ref": "ABD-123",
          "name": "Foo T-Shirt Size(L)",
          "quantity": 1,
          "price": 119.99,
          "options": {"color": "BLK", "size": "XL" }
        },
        {
          "name": "Foo Shoe",
          "sku": "DEF-123",
          "external_ref": "DDD-123",
          "name": "Foo Socks",
          "quantity": 3,
          "price": 23.99,
          "options": {"color": "BLK", "size": "XL" }
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
        "country": "US",
        "state": "Viriginia"
      },
      "payments": [
        {
          "amount": 129.99,
          "payment_method": "Standard"
        }
      ],
      "shipments": [
        {
          "cost": 29.99,
          "status": "ready",
          "stock_location": "PCH",
          "shipping_method": "UPS Next Day",
          "items": [
            {
              "name": "Foo T-Shirt Size(L)",
              "sku": "ABC-123",
              "external_ref": "ABD-123",
              "quantity": 1,
              "price": 119.99,              
              "options": {"color": "BLK", "size": "XL" }
            },
            {
              "name": "Foo Socks",
              "sku": "DEF-123",
              "external_ref": "DDD-123",
              "quantity": 3,
              "price": 23.99,              
              "options": {"color": "BLK", "size": "XL" }
            }
          ]
        }
      ]
    },
    "original": {
      "id": 900000,
      "number": "R123456789",
      "promotion": "123",
      "campaign": "456",
      "item_total": "112.99",
      "total": "129.99",
      "state": "complete",
      "adjustment_total": "10.00",
      "user_id": 8567,
      "created_at": "2013-09-20T16:24:22-04:00",
      "updated_at": "2013-09-20T16:24:22-04:00",
      "completed_at": "2013-09-20T16:24:22-04:00",
      "payment_total": "129.99",
      "shipment_state": "ready",
      "payment_state": "paid",
      "email": "test1@test.com",
      "special_instructions": null,
      "currency": "USD",
      "ship_total": "4.00",
      "tax_total": "6.00",
      "bill_address": { 
        "firstname": "Chris",
        "lastname": "Mar",
        "address1": "112 Hula Lane",
        "address2": "",
        "city": "Leesburg",
        "zipcode": "20175",
        "phone": "555-555-1212",
        "country": {
          "name": "US"
        },
        "state": {
          "abbr": "VA",
          "name": "Virginia"
        }
      },
      "ship_address": { },
      "line_items": [ { } ],
      "payments": [ { } ],
      "shipments": [ { } ],
      "adjustments": [ { } ],
      "credit_cards": [ { } ],
      "store_id": { "$oid": "62n8eaa2b4381934bc000001" },
      "next_id": null,
      "_id": "123poi67q98712304658mq8r"
    },
    "previous": {
      "number": "R123456789",
      "email": "test1@test.com",
      "currency": "USD",
      "placed_on": "2013-09-20T16:24:22-04:00",
      "updated_at": "2013-09-20T16:24:22-04:00",
      "status": "complete",
      "totals": {
        "item": 12.99,
        "adjustment": 10.0,
        "tax": 6.0,
        "shipping": 4.0,
        "payment": 29.99,
        "order": 29.99
      },
      "line_items": [ { } ],
      "adjustments": [ { } ],
      "shipping_address": { },
      "billing_address": { 
        "firstname": "Chris",
        "lastname": "Mar",
        "address1": "112 Hula Lane",
        "address2": "",
        "city": "Leesburg",
        "zipcode": "20175",
        "phone": "555-555-1212",
        "country": "US",
        "state": "Virginia"
      },
      "payments": [ { } ],
      "shipments": [ { } ]
    }
  }
}
```

### order:canceled

You should send this type of Message whenever an order is canceled, whether by the customer or by a store administrator.

---order_canceled.json---
```json
{
  "message": "order:canceled",
  "payload": {
    "parameters": [
      {
        "name": "access_token",
        "value": "eac97693-26be-11e3-9a20-856fcdde1271"
      },
      {
        
        "name": "refresh_token",
        "value": "eac6b772-26be-11e3-9a20-856fcdde1271"
      }
    ],
    "order": {
      "number": "R123456789",
      "channel": "Amazon",
      "email": "test1@test.com",
      "currency": "USD",
      "placed_on": "2013-09-20T16:24:22-04:00",
      "updated_at": "2013-09-20T16:24:22-04:00",
      "status": "complete",
      "totals": {
        "item": 12.99,
        "adjustment": 10,
        "tax": 6,
        "shipping": 4,
        "payment": 29.99,
        "order": 29.99
      },
      "adjustments": [
        {
          "name": "Shipping Discount",
          "value": "-4.99"
        },
        {
          "name": "Promotion Discount",
          "value": "-3.00"
        }
      ],
      "line_items": [
        {
          "name": "Foo T-Shirt Size(L)",
          "sku": "ABC-123",
          "external_ref": "ABD-123",
          "name": "Foo T-Shirt Size(L)",
          "quantity": 1,
          "price": 19.99,
          "options": {
            "color": "BLK", 
            "size": "XL" 
          }
        },
        {
          "name": "Foo Shoe",
          "sku": "DEF-123",
          "external_ref": "DDD-123",
          "name": "Foo Socks",
          "quantity": 3,
          "price": 23.99,
          "options": {
            "color": "BLK", 
            "size": "XL" 
          }
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
        "country": "US",
        "state": "Viriginia"
      },
      "payments": [
        {
          "number": 1234,
          "status": "completed",
          "amount": 29.99,
          "payment_method": "Standard"
        }
      ],
      "shipments": [
        {
          "number": "1234567",
          "cost": 29.99,
          "status": "ready",
          "stock_location": "PCH",
          "shipping_method": "UPS Next Day",
          "tracking": null,
          "updated_at": null,
          "shipped_at": null,
          "items": [
            {
              "name": "Foo T-Shirt Size(L)",
              "sku": "ABC-123",
              "external_ref": "ABD-123",
              "quantity": 1,
              "price": 19.99,              
              "variant_id": 123,
              "options": {
                "color": "BLK", 
                "size": "XL" 
              }
            },
            {
              "name": "Foo Socks",
              "sku": "DEF-123",
              "external_ref": "DDD-123",
              "quantity": 3,
              "price": 23.99, 
              "variant_id": 789,             
              "options": {
                "color": "BLK", 
                "size": "XL" 
              }
            }
          ]
        }
      ]
    },
    "original": {
      "id": 900000,
      "number": "R123456789",
      "promotion": "123",
      "campaign": "456",
      "item_total": "12.99",
      "total": "29.99",
      "state": "complete",
      "adjustment_total": "10.00",
      "user_id": 8567,
      "created_at": "2013-09-20T16:24:22-04:00",
      "updated_at": "2013-09-20T16:24:22-04:00",
      "completed_at": "2013-09-20T16:24:22-04:00",
      "payment_total": "29.99",
      "shipment_state": "ready",
      "payment_state": "paid",
      "email": "test1@test.com",
      "special_instructions": null,
      "currency": "USD",
      "ship_total": "4.00",
      "tax_total": "6.00",
      "bill_address": { 
        "firstname": "Chris",
        "lastname": "Mar",
        "address1": "112 Hula Lane",
        "address2": "",
        "city": "Leesburg",
        "zipcode": "20175",
        "phone": "555-555-1212",
        "country": {
          "name": "US"
        },
        "state": {
          "abbr": "VA",
          "name": "Virginia"
        }
      },
      "ship_address": { },
      "line_items": [ { } ],
      "payments": [ { } ],
      "shipments": [ { } ],
      "adjustments": [ { } ],
      "credit_cards": [ { } ],
      "store_id": { "$oid": "62n8eaa2b4381934bc000001" },
      "next_id": null,
      "_id": "123poi67q98712304658mq8r"
    }
  }
}
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| hubspot.access_token | Your HubSpot OAuth Token | aaa11111-11aa-11a1-1a11-111aaaaa1111 |
| hubspot.refresh_token | Your HubSpot OAuth Refresh Token | aaa11111-11aa-11a1-1a11-111aaaaa1111 |

#### Response

```json
{
  "message_id": "518726r84910515003",
  "notifications": [
    "level": "info",
    "subject": "Contact imported",
    "description": "The contact for order number R123456789 was imported."
  ]
}
```
