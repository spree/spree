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

Processes incoming orders that are new, updated, or canceled and either creates or updates the HubSpot contact that matches email address for the order. Mappings between fields are as follows:

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
    "order": {
      "number": "R123456789",
      "email": "test1@test.com",
      "totals": {
        "item": 12.99,
        "adjustment": 10,
        "tax": 6,
        "shipping": 4,
        "payment": 29.99,
        "order": 29.99
      },
      "adjustments": [
      ],
      "line_items": [
      ],
      "shipping_address": {
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
      ],
      "shipments": [
      ]
    },
    "original": {
      "id": 900000,
      "number": "R123456789",
      "promotion": "123",
      "campaign": "456",
      "item_total": "12.99",
      "total": "29.99",
      "adjustment_total": "10.00",
      "payment_total": "29.99",
      "email": "test1@test.com",
      "ship_total": "4.00",
      "tax_total": "6.00",
      "completed_at": "2013-09-20T16:24:22-04:00",
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
      "credit_cards": [ { } ]
    }
  }
}
```

### order:updated

This type of message is generated when an existing order is updated.

---order_updated.json---
```json
{
  "message": "order:updated",
  "payload": {
    "order": {
      "email": "test1@test.com",
      "totals": {
        "item": 112.99,
        "adjustment": 10,
        "tax": 6,
        "shipping": 4,
        "order": 129.99
      },
      "adjustments": [
      ],
      "line_items": [
      ],
      "shipping_address": {
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
      ],
      "shipments": [
      ]
    },
    "original": {
      "id": 900000,
      "number": "R123456789",
      "promotion": "123",
      "campaign": "456",
      "item_total": "112.99",
      "total": "129.99",
      "adjustment_total": "10.00",
      "completed_at": "2013-09-20T16:24:22-04:00",
      "payment_total": "129.99",
      "email": "test1@test.com",
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
      "credit_cards": [ { } ]
    },
    "previous": {
      "number": "R123456789",
      "email": "test1@test.com",
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

This type of message is sent whenever an order is canceled, whether by the customer or by a store administrator.

---order_canceled.json---
```json
{
  "message": "order:canceled",
  "payload": {
    "order": {
      "number": "R123456789",
      "email": "test1@test.com",
      "totals": {
        "item": 12.99,
        "adjustment": 10,
        "tax": 6,
        "shipping": 4,
        "payment": 29.99,
        "order": 29.99
      },
      "adjustments": [
      ],
      "line_items": [
      ],
      "shipping_address": {
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
      ],
      "shipments": [
      ]
    },
    "original": {
      "id": 900000,
      "number": "R123456789",
      "promotion": "123",
      "campaign": "456",
      "item_total": "12.99",
      "total": "29.99",
      "adjustment_total": "10.00",
      "completed_at": "2013-09-20T16:24:22-04:00",
      "payment_total": "29.99",
      "email": "test1@test.com",
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
      "credit_cards": [ { } ]
    }
  }
}
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| hubspot.access_token | Your HubSpot OAuth Access Token | aaa11111-11aa-11a1-1a11-111aaaaa1111 |
| hubspot.refresh_token | Your HubSpot OAuth Refresh Token | aaa11111-11aa-11a1-1a11-111aaaaa1111 |

Your access token is generated via the API Access section of your HubSpot administration area. You need to use an authorization URL to grant permission to the Hub to access and modify your HubSpot account data, which will also generate a refresh token. Contact Spree Commerce technical support to complete this process.

Once your refresh token has been created, the Hub will use it to automatically update your access token once it expires, as HubSpot tokens are only good for 8 hours.

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
