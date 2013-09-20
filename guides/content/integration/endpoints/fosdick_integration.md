---
title: Fosdick Endpoint
---

## Overview

[Fosdick](http://www.fosdickfulfillment.com/) is a company that specializes in direct-to-consumer fullfillment.

+++
The source code for the [Fosdick Endpoint](https://github.com/spree/fosdick_endpoint/) is available on Github.
+++

## Services

### Send Shipment

Send a shipment to Fosdick .

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

### Response

---notification_info.json---

```json
{
  "notifications": [
    {
      "level": "info",
      "subject": "Successfully Sent Shipment to Fosdick",
      "description": "Successfully Sent Shipment to Fosdick"
    }
  ]
}
```

### Poll For Shipment Result Files

Check an S3 bucket to see if there are any shipment result files ready to be downloaded

---fosdick_shipment_results_poll.json---

### Request

{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "fosdick:shipment_results:poll",
  "payload": {}
}

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| fosdick.amazon_key | Your AWS key | Aqws3958dhdjwb39 |
| fosdick.amazon_secret_key | Your AWS Secret Key | dj20492dhjkdjeh2838w7 |
| fosdick.s3_bucket | Name Of The S3 Bucket | fosdick |

### Response

```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "shipment:confirm",
  "payload": {
    "shipment": {
      "number": "70201201334520004",
      "order_number": "104-0444357-8954627",
      "tracking_number": "915293072790136"
    }
  }
}
```