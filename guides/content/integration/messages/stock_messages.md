---
title: Stock Messages
---

## Overview
Changing the stock amount for a specific Variant by his SKU.

By default stock backordering will be respected. To turn this off add a boolean parameter ```spree.force_quantity``` with ```true``` to set the stock amount exactly the same as the quantity provided.

## Message Types

### stock:change

This message will change the ```count_on_hand``` for a ```Spree::Variant``` based on the provided sku and the quantity. The quantity can be negative!. 

!!!
It's impossible to create any backorders for a Spree 1.3 store since the logic is tied to Orders and InventoryUnits. An ```InvalidQuantityException``` will be raised when that's happening.
!!!

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

### stock:actual

This message will set the ```count_on_hand``` for a ```Spree::Variant``` based on the provided sku and the quantity. The quantity can be negative!. This message will always force the quantity.

!!!
It's impossible to create any backorders for a Spree 1.3 store since the logic is tied to Orders and InventoryUnits. An ```InvalidQuantityException``` will be raised when that's happening.
!!!

---stock_actual.json---
```json
{
  "message_id": "51af1dc5fe53543f1200f519",
  "message": "stock:actual",
  "payload": {
    "sku": "ROR-001234",
    "quantity": 20
  }
}
```