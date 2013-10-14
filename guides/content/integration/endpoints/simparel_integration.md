---
title: Simparel Endpoint
---

## Overview

[Simparel](http://simparel.com/) is a fashion ERP.

+++
The source code for the [Simparel](https://github.com/spree/simparel_endpoint/) is available on Github.
+++

## Requirements

The Simparel Endpoint operates with the assumption that there is an existing API that interfaces with the Simparel Database with the following routes

* /production_shipping_notices
* /production_shipping_notices/:id
* /production_shipping_notices/:id/items
* /transfer_shipping_notices
* /transfer_shipping_notices/:id
* /transfer_shipping_notices/:id/items
* /transfer_shipping_requests
* /transfer_shipping_requests/:id
* /transfer_shipping_requests/:id/items
* /sales_order_notices
* /sales_order_notices/:id
* /sales_order_notices/:id/items
# /products
# /products/:id

## Services

### Poll for Purchase Orders

Poll the simparel api for pending purchase orders. A purchase order is comprised of production_shipping_notices and transfer_shipping_notices.

#### Request

---purchase_order_poll.json---

```json
{
  "message_id": "5acdgg35sf4563f",
  "message": "purchase_order:poll",
  "payload": {}
}
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| simparel api url | Url to access the api | https://simparelapi.spree.com |
| username| Basic Auth username | test |
| password | Basic Auth Password | test |

#### Response

```json
{
  "message_id": "5sfd3tehg4642",
  "messages": [
    {
      "message": "purchase_order:new",
      "payload": {
        "purchase_order": {
          "po_number": "10511_TI-41355",
          "client_id": "Spree",
          "business_unit": "SPREE",
          "alt_po_number": 10511,
          "arrival_date": "2013-09-19 00:00:00 +0000",
          "order_date": "2013-05-16 00:00:00 +0000",
          "comments": "",
          "warehouse": "QL",
          "vendor": {
            "type": "Vendor",
            "name": "JOE",
            "vendorid": "JOE001",
            "address": {
              "address1": "",
              "address2": "",
              "address3": "",
              "address4": "",
              "city": "",
              "country": "",
              "zip": "",
              "state": ""
            },
            "contact": {
              "name": "",
              "email": "",
              "phone": ""
            }
          },
          "line_items": [
            {
              "quantity": 6,
              "itemno": "123456",
              "line_item_number": 2,
              "description": "Hoodie",
              "unit_price": "33.35"
            }
          ]
        }
      }
    }
  ]
}
```

### Poll for Shipment Orders

Poll the simparel api for pending shipment orders. A purchase order is comprised of transfer_shipping_requests and sales_order_notices.

#### Request

---shipment_order_poll.json---

```json
{
  "message_id": "5acdgg35sf4563f",
  "message": "shipment_order:poll",
  "payload": {}
}
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| simparel api url | Url to access the api | https://simparelapi.spree.com |
| username| Basic Auth username | test |
| password | Basic Auth Password | test |

#### Response

```json
{
  "message_id": "5weff3356gdsg",
  "messages": [
    {
      "message": "shipment_order:new",
      "payload": {
        "shipment_order": {
          "shipment_number": "T100121_20094",
          "order_date": "2013-09-19T20:03:52Z",
          "order_type": "TO",
          "client_id": "SPREE",
          "business_unit": "SPREE",
          "comments": "",
          "ship_mode": {
            "carrier": "UPS",
            "service_level": "GROUND"
          },
          "ship_to": {
            "warehouse_id": "JOE01",
            "name": "JOE",
            "address": {
              "address1": "",
              "address2": "",
              "address3": null,
              "address4": null,
              "city": "",
              "country": "",
              "zip": "",
              "state": ""
            }
          },
          "bill_to": {
            "warehouse_id": "JOE01",
            "name": "JOE",
            "address": {
              "address1": "",
              "address2": "",
              "address3": null,
              "address4": null,
              "city": "",
              "country": "",
              "zip": "",
              "state": ""
            }
          },
          "line_items": [
            {
              "description": "Denim",
              "itemno": "965564",
              "quantity_ordered": 1,
              "quantity_to_ship": 1,
              "line_item_number": 1,
              "price": 0.0,
              "UOM": "EA"
            }
          ]
        }
      }
    }
  ]
}
```

### Confirm Purchase Order

Mark a purchase order confirmed once the purchase order has been trasmitted

#### Request

```json
{
  "message_id": "5aeg46nes4nwl",
  "message": "purchase_order:transmit",
  "payload": {
    "purchase_order": {
      "order_id": "10572_TI-41355",
      "warehouse": "QL",
      "order_date": "2013-05-17 00:00:00 +0000",
      "vendor": {
        "type": "Vendor",
        "name": "",
        "vendorid": "",
        "address": {
          "address1": "",
          "address2": "",
          "address3": "",
          "address4": "",
          "city": "",
          "country": "",
          "zip": "",
          "state": ""
        },
        "contact": {
          "name": "",
          "email": "",
          "phone": ""
        }
      }
    }
  }
}
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| simparel api url | Url to access the api | https://simparelapi.spree.com |
| username| Basic Auth username | test |
| password | Basic Auth Password | test |


#### Response

```json
{
  "message_id": "5acdfd45xvsg",
  "notifications": [
    {
      "level": "info",
      "subject": "Confirmed purchase order",
      "description": "ID: 10572_TI-41355"
    }
  ]
}
```

### Confirm Shipment Order

Marks a shipment order confirmed once it has been transmitted.

#### Request

```json
{
  "message_id": "52dadsgs363f",
  "message": "shipping_order:transmit",
  "payload": {
    "shipping_order": {
      "order_id": "T100121_20094",
      "ship_to": {
        "warehouse_id": "SPR01",
        "name": "SPREE",
        "address": {
          "address1": "",
          "address2": "",
          "address3": null,
          "address4": null,
          "city": "",
          "country": "",
          "zip": "",
          "state": ""
        }
      }
    }
  }
}
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| simparel api url | Url to access the api | https://simparelapi.spree.com |
| username| Basic Auth username | test |
| password | Basic Auth Password | test |


#### Response

```json
{
  "message_id": "523b58b3b43957333800f3fa",
  "notifications": [
    {
      "level": "info",
      "subject": "Confirmed shipping order",
      "description": "ID: T100121_20094"
    }
  ]
}
```

### Receive Purchase Order

Mark a purchase order as received

#### Request

```json
{
  "message_id": "5adf355fdaa",
  "message": "purchase_order:received",
  "payload": {
    "purchase_order": {
      "po_number": "10612_AI-41189",
      "items": [
        {
          "line_number": "23",
          "itemno": "997340",
          "quantity": "4",
          "receivedate": "2013-09-22T17:17:20.437426Z"
        }
      ]
    }
  }
}
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| simparel api url | Url to access the api | https://simparelapi.spree.com |
| username| Basic Auth username | test |
| password | Basic Auth Password | test |

#### Response

```json
{
  "message_id": "523f286ab4395733380178f5",
  "notifications": [
    {
      "level": "info",
      "subject": "Received Purchase Order",
      "description": "Succesfully Received PO: 10612_AI-41189"
    }
  ]
}
```



