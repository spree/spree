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
  "message": "purchase_order.new",
  "payload": {
    "purchase_order": {
      "po_number": "123456",
      "client_id": "SPREE",
      "business_unit": "SPREE",
      "alt_po_number": 1234,
      "arrival_date": "2013-07-19 00:00:00 +0000",
      "order_date": "2013-04-09 00:00:00 +0000",
      "comments": "SWEATSHIRTS",
      "warehouse": "QL",
      "vendor": {
        "type": "Vendor",
        "name": "JOE Vendor",
        "vendorid": "JOE001",
        "address": {
          "address1": "1234 Test Lane",
          "address2": "",
          "address3": "",
          "address4": "",
          "city": "Bethesda",
          "country": "",
          "zip": "",
          "state": "MD"
        },
        "contact": null
        },
        "line_items": [
          {
            "quantity": 12,
            "itemno": "968066",
            "line_item_number": 7,
            "description": "Sweats-Grey",
            "unit_price": "20.98"
          },
          {
            "quantity": 41,
            "itemno": "968065",
            "line_item_number": 8,
            "description": "Sweats-Grey",
            "unit_price": "20.98"
          },
          {
            "quantity": 86,
            "itemno": "968064",
            "line_item_number": 9,
            "description": "Sweats-Grey",
            "unit_price": "20.98"
          },
          {
            "quantity": 49,
            "itemno": "968063",
            "line_item_number": 10,
            "description": "Sweats-Grey",
            "unit_price": "20.98"
          },
          {
            "quantity": 18,
            "itemno": "968062",
            "line_item_number": 11,
            "description": "Sweats-Grey",
            "unit_price": "20.98"
          },
          {
            "quantity": 2,
            "itemno": "968061",
            "line_item_number": 12,
            "description": "Sweats-Grey",
            "unit_price": "20.98"
          },
          {
            "quantity": 12,
            "itemno": "970329",
            "line_item_number": 13,
            "description": "Sweats-Grey",
            "unit_price": "18.48"
          }
        ]
      }
    }
  }
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| quiet_logistics.amazon_access_key | Your AWS Access Key | Aqws3958dhdjwb39 |
| quiet_logistics.amazon_secret_key | Your AWS Secret Key | dj20492dhjkdjeh2838w7 |
| quiet_logistics.ql_outgoing_queue | Name of the SQS queue to send messages to | ql_outgoing_queue |
| quiet_logistics.ql_outgoing_bucket | Name of the S3 bucket to send documents to | ql-outgoing-bucket |

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
          "sqs_id": "12132-23523523-13512412",
          "s3_url": "http://test-bucket.s3.amazonaws.com/TEST_DOC.xml",
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
      {
        "shipment_number": "T100044_20024",
        "order_date": "2013-09-05T17:19:28Z",
        "order_type": "TO",
        "client_id": "SPREE",
        "comments" : '',
        "business_unit": "SPREE",
        "ship_mode": {
          "carrier": "UPS",
          "service_level": "GROUND"
        },
        "ship_to": {
          "name": "Spree",
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
        },
        "line_items": [
          {
            "description": "Washed Chinos",
            "itemno": "332110",
            "quantity_ordered": 1,
            "quantity_to_ship": 1,
            "line_item_number": 1,
            "price": 24.49,
            "UOM": "EA"
          }
        ]
      }
    }
  }
}
```

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| quiet_logistics.amazon_access_key | Your AWS Access Key | Aqws3958dhdjwb39 |
| quiet_logistics.amazon_secret_key | Your AWS Secret Key | dj20492dhjkdjeh2838w7 |
| quiet_logistics.ql_outgoing_queue | Name of the SQS queue to send messages to | ql_outgoing_queue |
| quiet_logistics.ql_outgoing_bucket | Name of the S3 bucket to send documents to | ql-outgoing-bucket |


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
          "sqs_id": "1214-2453-35325",
          "s3_url": "http://test-bucket.s3.amazonaws.com/TEST_DOC.xml"
          "ship_to": {
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

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| quiet_logistics.amazon_access_key | Your AWS Access Key | Aqws3958dhdjwb39 |
| quiet_logistics.amazon_secret_key | Your AWS Secret Key | dj20492dhjkdjeh2838w7 |
| quiet_logistics.ql_outgoing_queue | Name of the SQS queue to send messages to | ql_outgoing_queue |
| quiet_logistics.ql_outgoing_bucket | Name of the S3 bucket to send documents to | ql-outgoing-bucket |


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

#### Parameters

| Name | Value | Example |
| :----| :-----| :------ |
| quiet_logistics.amazon_access_key | Your AWS Access Key | Aqws3958dhdjwb39 |
| quiet_logistics.amazon_secret_key | Your AWS Secret Key | dj20492dhjkdjeh2838w7 |
| quiet_logistics.ql_incoming_queue | Name of the SQS queue to read messages from | ql_incoming_queue |

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

#### Parameters

| Name | Value | Example |
| quiet_logistics.amazon_access_key | Your AWS Access Key | Aqws3958dhdjwb39 |
| quiet_logistics.amazon_secret_key | Your AWS Secret Key | dj20492dhjkdjeh2838w7 |
| quiet_logistics.ql_incoming_bucket | Name of the S3 bucket to read documents from | ql-incoming-bucket |

### Response (ShipmentOrderResult)

---ql_shipment_confirm.json---

```json
{
  "message_id": "521be5fdb439572325001d2d",
  "messages": [
    {
      "message": "ql:shipment:confirm",
      "payload": {
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

#### Parameters

| Name | Value | Example |
| quiet_logistics.amazon_access_key | Your AWS Access Key | Aqws3958dhdjwb39 |
| quiet_logistics.amazon_secret_key | Your AWS Secret Key | dj20492dhjkdjeh2838w7 |
| quiet_logistics.ql_incoming_queue | Name of the SQS queue to read messages from | ql_incoming_queue |

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