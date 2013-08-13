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
}```

### shipping_order:transmit

Indicates that a new shipping order was successfuly transmitted to Quiet Logistics.

!!!
This only means that the message was successfully placed on the SQS queue used by QL to process this type of request. QL may end up rejecting the API request at a later point and signal a problem by placing an error message on the store's queue
!!!

---purchase_order_transmit.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "shipping_order:transmit",
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
