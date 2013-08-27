---
title: Quiet Logistics Endpoint
---

## Overview

[Quiet Logistics](http://quietlogistics.com/) is a company specializing in third party fullfillment. Quiet Logistics utilizes Amazon's Web Services to provide an API for sending and receiving documents. When transmitting a document to Quiet Logistics an event message must be sent to SQS and a corresponding document must be sent to S3. When receiving messages from Quiet Logistics, messages are read from an incoming SQS queue and documents are downloaded from an incoming S3 bucket.

+++
The source code for the [Quiet Logistics Endpoint](https://github.com/spree/quiet_logistics_endpoint/)  is available on Github.
+++

## Services

### Transmit PO

Indicates that a new purchase order was successfuly transmitted to Quiet Logistics.

***
This only means that the message was successfully placed on the SQS queue and the S3 bucket used by QL to process this type of request. QL may end up rejecting the API request at a later point and signal a problem by placing an error message on the store's queue
***

####Request

---purchase_order_new.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "purchase_order:new",
  "payload": {
    "purchase_order": {
      "order_id": 123,
      "shipment_id": "456",
      "shipping_notice_id": "1111111",
      "simparel_notice_id": "123_456",
      "arrival_date": "2013-07-19 00:00:00 +0000",
      "order_date": "2013-04-09 00:00:00 +0000",
      "title": "SWEATSHIRTS",
      "warehouse": "QL",
      "vendor": {
        "type": "Vendor",
        "name": "JOE VENDOR",
        "vendorid": "JOE1",
        "address": {
          "address1":"",
          "address2":"",
          "address3":"",
          "address4":"",
          "city":"",
          "country":"",
          "zip":"",
          "state":""
        },
        "contact": null
      },
      "line_items": [
        {
          "quantity":12,
           "itemno":68627,
           "line_item_number":7,
           "item_size":"XS",
           "description":"",
           "upc":"1234567",
           "whs_item_id":"13341",
           "ql_sku":"999999",
           "ql_description":"Sweats-Grey",
           "unit_price":"20.98",
           "total_price":"251.76"
         },
        {
          "quantity":41,
           "itemno":68626,
           "line_item_number":8,
           "item_size":"S",
           "description":"",
           "upc":"1234567",
           "whs_item_id":"13341",
           "ql_sku":"999999",
           "ql_description":"Sweats-Grey",
           "unit_price":"20.98",
           "total_price":"860.18"
         }
      ]
    }
  }
}
```


#### Response

---purchase_order_transmit.json---

```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "messages" [
    {
      "message": "purchase_order:transmit",
      "payload": {
        "purchase_order": {
          "order_id": "123",
          "shipping_notice_id": "123_456",
          "warehouse": "QL",
          "order_date": "2013-08-07 00:00:00 +0000",
          "vendor": {
            "type": "vendor",
            "vendorid": "JOE1",
            "name": "JOE VENDOR",
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
  ]
}
```

### Transmit SO

Indicates that a new shipment order was successfuly transmitted to Quiet Logistics.

***
This only means that the message was successfully placed on the SQS queue and S3 bucket used by QL to process this type of request. QL may end up rejecting the API request at a later point and signal a problem by placing an error message on the store's queue
***


#### Request
---shipment_order.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "shipment_order:new",
  "payload": {
    "shipment_order": {
      "order_id": "123",
      "shipment_id": 456,
      "shipping_notice_id": "88833337",
      "simparel_notice_id": "123_456",
      "source_warehouse": {
        "warehouse_id": "QL",
        "name": "QUIET LOGISTICS",
        "address": {
          "address1": "ATTN Bonobos",
          "address2": "66 Saratoga Blvd",
          "address3":null,
          "address4":null,
          "city": "Devens",
          "country": "US",
          "zip": "01434",
          "state": "MA"
        }
      },
      "destination_warehouse": {
        "warehouse_id": "EX01",
        "name": "EXAMPLE WAREHOUSE",
        "address": {
          "address1": "123 example lane",
          "address2": "",
          "address3": null,
          "address4": null,
          "city": "New York",
          "country": "US",
          "zip": "10010",
          "state": "NY"
        }
      },
      "line_items": [
        {
          "itemno": 123456,
          "quantity": 1,
          "price": 24.49,
          "upc": "986885",
          "whs_item_id": "11598-3452",
          "ql_sku": "99999",
          "ql_description": "Blue Jeans",
          "line_item_number":1,
          "description": "loose fit jeans"
        }
      ],
      "due_date":null,
      "ship_date": "2013-08-05 00:00:00 +0000"
    }
  }
}
```

#### Response
---shipping_order_transmit.json---

```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "messages": [
    {
      "message": "shipping_order:transmit",
      "payload": {
        "shipping_order": {
          "order_id": "T100045",
          "shipping_notice_id": "100045_20025",
          "source_warehouse": {
            "warehouse_id": "QL",
            "address": {
              "address1": "ATTN Bonobos",
              "address2": "66 Saratoga Blvd",
              "address3": null,
              "address4": null,
              "city": "Devens",
              "country": "US",
              "zip": "01434",
              "state": "MA"
            }
          },
          "destination_warehouse": {
            "warehouse_id": "GSNY1",
            "address": {
              "address1": "45 W 25th St",
              "address2": "5th Floor",
              "address3": null,
              "address4": null,
              "city": "New York",
              "country": "US",
              "zip": "10010",
              "state": "NY"
            }
          }
        }
      }
    }
  ]
}
```

### Transmit Product

Sends an item profile document containing the product and packaging attributes for the client products.

***
This only means that the message was successfully placed on the SQS queue and S3 bucket used by QL to process this type of request. QL may end up rejecting the API request at a later point and signal a problem by placing an error message on the store's queue
***

#### Request
---product_update.json---

```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "product:update",
  "payload": {
    "product" {
      "item_size": "XXL",
      "itemno": 12345,
      "description": "",
      "material": "100% COTTON",
      "vendor_name": "Example Vendor",
      "vendor_item_no": "POL-112-123",
      "image_url": null,
      "upc": "885468",
      "whs_item_id": "12345-EL965-XXL",
      "commodity_class": "shirt",
      "color_name": "blue",
      "customer_attributes": [
        {
          "customer": "QL",
          "sku": "967103",
          "description": "Golf Knit-Chambray Golf"
        }
      ]
    }
  }
}
```


#### Response
---notification.json---

```json
{
  "message_id": "521be5fdb439572325001d2d",
  "notifications": [
    {
      "level": "info",
      "subject": "ItemProfile Document Successfuly Sent",
      "description": "SQS Id: e9ccc237-5129-44d1-9bb5-2f38247cb7cd S3 url: https://bonobos-to-quiet.s3.amazonaws.com/ItemProfile_963527_20130826_2334418.xml?AWSAccessKeyId=AKIAIK6HSAJEIKESRW3A&Expires=1377563677&Signature=Q0tSRmR3FbR6gw1jyMBUMC7SyWs%3D"
    }
  ]
}
```

### Poll For SQS Messages

Polls a SQS queue for incoming messages sent by Quiet Logistics.

### Request
---quiet_logistics_messages_poll.json---
```json

{
  "message_id": "521be5fdb439572325001d2d",
  "message": "quiet_logistics:messages:poll",
  "payload": {}
}
```

### Response
---quiet_logistics_document_download.json---

```json
{
  "message_id": "521be5fdb439572325001d2d",
  "messages": [
    {
      "message": "quiet_logistics:document:download",
      "payload": {
        {
          "document_name": "SoResultV2_600110212_20130823_140441759.xml",
          "document_type": "ShipmentOrderResult",
          "message_date": "2013-08-23T14:05:03.9009948-04:00",
          "original_message_id": "76f2ed1c-7bb3-4106-86c4-547d1e3d1929"
        }
      }
    }
  ]
}
```

### Download Document From S3

Retrieves a document from a Quiet Logistics S3 bucket. The response message will vary depending on what type of document is downloaded. A ShipmentOrderResult will generate a ql:shipment:confirmation message whereas a PurchaseOrderReceipt will generate a purchase_order:received message.

#### Request (ShipmentOrderResult)

---quiet_logistics_document_download.json---

```json
{
  "message_id": "521be5fdb439572325001d2d",
  "messages": [
    {
      "message": "quiet_logistics:document:download",
      "payload": {
        {
          "document_name": "SoResultV2_600110212_20130823_140441759.xml",
          "document_type": "ShipmentOrderResult",
          "message_date": "2013-08-23T14:05:03.9009948-04:00",
          "original_message_id": "76f2ed1c-7bb3-4106-86c4-547d1e3d1929"
        }
      }
    }
  ]
}
```

### Response (ShipmentOrderResult)

---ql_shipment_confirm.json---

```json
{
  "message_id": "521be5fdb439572325001d2d",
  "messages": [
    {
      "message": "ql:shipment:confirm",
      "payload": {
        "type": "shipment_order_result",
        "number": "T600110212",
        "warehouse": "QL"
      }
    }
  ]
}

```

#### Request (PurchaseOrderReceipt)

---quiet_logistics_document_download.json---

```json
{
  "message_id": "521be5fdb439572325001d2d",
  "messages": [
    {
      "message": "quiet_logistics:document:download",
      "payload": {
        {
          "document_name": "PoReceiptV2_600110212_20130823_140441759.xml",
          "document_type": "PurchaseOrderReceipt",
          "message_date": "2013-08-23T14:05:03.9009948-04:00",
          "original_message_id": "76f2ed1c-7bb3-4106-86c4-547d1e3d1929"
        }
      }
    }
  ]
}
```

#### Response (PurchaseOrderReceipt)

Indicates that a purchase order was received by Quiet Logistics.

---purchase_order_received.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "messages": [
    {
      "message": "purchase_order:received",
      "payload": {
        "purchase_order": {
          "po_number": "8735",
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
  ]
}
```