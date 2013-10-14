---
title: VPD Endpoint
---

## Overview

[Video Products Distributors](http://www.vpdinc.com) are one of the nation's leading wholesalers of home entertainment products, including DVDs, Blu-Ray and video games, to retailers throughout the US.

## Services

### Send Shipment

Send's shipment details to VPD.

#### Request

---shipment_ready.json---
```json
{
    "message_id": "51af1dc5fe53543f1200f519",
    "message": "shipment:ready",
    "payload": {
      "shipment": {
        "number": "H67606710123",
        "order_number": "R805661123",
        "email": "brian@spreecommerce.com",
        "cost": 10.0,
        "status": "ready",
        "stock_location": null,
        "shipping_method": "Standard",
        "tracking": null,
        "updated_at": null,
        "shipped_at": null,
        "shipping_address": {
          "firstname": "Brian",
          "lastname": "Quinn",
          "address1": "2 Wisconsin Cir.",
          "address2": "",
          "zipcode": "20815",
          "city": "Chevy Chase",
          "state": "Maryland",
          "country": "US",
          "phone": "555-123-123"
        },
        "items": [
          {
            "name": "Socks",
            "sku": "9011CC",
            "external_ref": "",
            "quantity": 1,
            "price": 29.0,
            "variant_id": 4123,
            "options": {
              "size": "M",
              "color": "BLK"
            }
          },
          {
            "name": "Shoes",
            "sku": "2001SSBM",
            "external_ref": "",
            "quantity": 1,
            "price": 27.0,
            "variant_id": 4321,
            "options": {
              "option-name": "value"
            }
          },
          {
            "name": "Feet",
            "sku": "2002SSBS",
            "external_ref": "",
            "quantity": 1,
            "price": 29.0,
            "variant_id": 1234,
            "options": {
              "toes": "present"
            }
          }
        ]
      },
      "order": {},
      "original": {}
      ]
    }
}
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| vpd.customer_id | Your VPD Customer ID | 110112 |


#### Response

---notification_info.json---

```json
{
  "notifications": [
    {
      "level": "info",
      "subject": "Successfully sent shipment to VPD",
      "description": "Successfully sent shipment to VPD"
    }
  ]
}
```

### Shipment Pickups

Once shipments have be packaged, and collected by the delivery service you can poll for pickup details:

#### Request

---vpd_shipment_pickup_poll.json---
```json

{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "vpd:shipment:pickup:poll",
  "payload": {}
}
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| vpd.customer_id | Your VPD Customer ID | 110112 |
| vpd.last_pickup_shipment | The shipment number for last succesfully polled pickup shipment | H123123123 |

#### Response

---vdp_shipment_pickup_response.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "messages": [
    "message": "vpd:shipment:pickup",
    "payload": {
      "shipment": {
        "number": "H12312312",
        "order_number": "R123123123",
        "pickup_confirmation": "RRD05059123881878"
      }
    }
  ]
}
```

### Shipment Confirmation

Once shipments have been confirmed as dispatched by the delivery service you can poll for confirmation details:

#### Request

---vpd_shipment_confirmation_poll.json---
```json

{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "vpd:shipment:confirmation:poll",
  "payload": {}
}
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| vpd.customer_id | Your VPD Customer ID | 110112 |
| vpd.last_confirmation_shipment | The shipment number for last succesfully polled confirmation shipment | H123123123 |

#### Response

---vdp_shipment_confirmation_response.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "messages": [
    "message": "shipment:confirm",
    "inflate": true,
    "payload": {
      "shipment": {
        "number": "H12312312",
        "order_number": "R123123123",
        "tracking": "123123123123123132123VR"
      }
    }
  ]
}
```


### Stock Level Queries

You can query the VPD stock levels for given SKU's by passing `stock:query` messages.

#### Request

---vp_stock_query_resquest.json---
```json

{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "stock:query",
  "payload": {
    "sku": "ABC-123"
  }
}
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| vpd.customer_id | Your VPD Customer ID | 110112 |

#### Response

---vdp_shipment_confirmation_response.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "messages": [
    {
      "message": "stock:actual",
      "payload": {
        "sku": "ABC-123"
        "quantity": 550
      }
    }
  ]
}
```

**NOTE:** The spree_endpoint can be configured to process `stock:actual` messages and set the stock levels for the given SKU.
