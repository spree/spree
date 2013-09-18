---
title: Stock Messages
---

## Overview
Changing the stock amount for a specific Variant by his SKU.

By default stock backordering will be respected. To turn this off add a boolean parameter ```spree.respect_backordering``` with ```false``` to set the stock amount exactly the same as the quantity provided.

***
With connected Spree stores before 2.0, we will always respect the backordering. Setting ```spree.respect_backordering``` to false will be ignored for these stores
***

## Message Types

### stock:change

---stock_change.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "stock:change",
  "payload": {
    "sku": "ROR-001234",
    "quantity": 20
  }
}
```