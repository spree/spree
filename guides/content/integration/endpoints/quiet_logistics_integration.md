---
title: Quiet Logistics Endpoint
---

## Overview

## Messages Generated

### purchase_order:transmit

Indicates that a new purchase order was successfuly transmitted to Quiet Logistics.

!!!
This only means that the message was successfully placed on the SQS queue used by QL to process this type of request. QL may end up rejecting the API request at a later point and signal a problem by placing an error message on the store's queue
!!!

---purchase_order_transmit.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "purhcase_order:transmit",
  "payload": {
    "purchase_order": {
      "order_id": "T100045",
      "shipping_notice_id": "100045_20025",
      "warehouse": "QL",
      "order_date": "2013-08-07 00:00:00 +0000",
      "vendor": {
        "type": "vendor",
        "vendorid": "GSNY1",
        "name": "GUIDESHOP NY1 - HQ",
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
}```

### shipping_order:transmit

Indicates that a new shipping order was successfuly transmitted to Quiet Logistics.

!!!
This only means that the message was successfully placed on the SQS queue used by QL to process this type of request. QL may end up rejecting the API request at a later point and signal a problem by placing an error message on the store's queue
!!!

---shipping_order_transmit.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
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
}```

### purchase_order:received

Indicates that a purchase order was received by Quiet Logistics.

---purchase_order_received.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "purchase_order:received",
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
        },
        {
          "line": "3",
          "item_number": "334394",
          "quantity": "33",
          "date": "2012-08-22T20:25:45.286285Z"
        },
        {
          "line": "4",
          "item_number": "334395",
          "quantity": "64",
          "date": "2012-08-22T20:25:45.286285Z"
        },
        {
          "line": "5",
          "item_number": "334396",
          "quantity": "3",
          "date": "2012-08-22T20:25:45.286285Z"
        },
        {
          "line": "6",
          "item_number": "334397",
          "quantity": "19",
          "date": "2012-08-22T20:25:45.286285Z"
        },
        {
          "line": "7",
          "item_number": "334399",
          "quantity": "5",
          "date": "2012-08-22T20:25:45.286285Z"
        },
        {
          "line": "8",
          "item_number": "334379",
          "quantity": "33",
          "date": "2012-08-22T20:25:45.286285Z"
        },
        {
          "line": "9",
          "item_number": "334382",
          "quantity": "31",
          "date": "2012-08-22T20:25:45.286285Z"
        },
        {
          "line": "10",
          "item_number": "334383",
          "quantity": "91",
          "date": "2012-08-22T20:25:45.286285Z"
        },
        {
          "line": "11",
          "item_number": "334384",
          "quantity": "120",
          "date": "2012-08-22T20:25:45.286285Z"
        },
        {
          "line": "12",
          "item_number": "334385",
          "quantity": "5",
          "date": "2012-08-22T20:25:45.286285Z"
        },
        {
          "line": "13",
          "item_number": "334387",
          "quantity": "45",
          "date": "2012-08-22T20:25:45.286285Z"
        },
        {
          "line": "14",
          "item_number": "334402",
          "quantity": "37",
          "date": "2012-08-22T20:25:45.286285Z"
        },
        {
          "line": "15",
          "item_number": "334403",
          "quantity": "126",
          "date": "2012-08-22T20:25:45.286285Z"
        },
        {
          "line": "16",
          "item_number": "334404",
          "quantity": "75",
          "date": "2012-08-22T20:25:45.286285Z"
        },
        {
          "line": "17",
          "item_number": "334405",
          "quantity": "82",
          "date": "2012-08-22T20:25:45.286285Z"
        },
        {
          "line": "18",
          "item_number": "334406",
          "quantity": "40",
          "date": "2012-08-22T20:25:45.286285Z"
        },
        {
          "line": "19",
          "item_number": "334408",
          "quantity": "18",
          "date": "2012-08-22T20:25:45.286285Z"
        }
      ]
    }
  }
}```

### ql:shipment:confirm

Indicates that Quiet Logistics has shipped the specified shipment.

---ql_shipment_confirm.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "ql:shipment:confirm",
}```

### document:download

Contains the necessary information to download an XML document from S3 that corresponds to an SQS message.

---document_download.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "document:download",
}```
