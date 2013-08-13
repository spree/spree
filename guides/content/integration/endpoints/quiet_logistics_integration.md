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
