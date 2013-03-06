---
title: "Core | Models | Line Item"
---

# LineItem

Line items are used to keep track of items within the context of an
[Order](/developer/core/models/order). These records provide a link between orders,
and [Variants](/developer/core/models/variant)

When a variant is added to an order, the price of that item is tracked along
with the line item to preserve that data. If the variant's price were to change,
then the line item would still have a record of the price at the time of ordering.

* Inventory tracking notes to go here after Chris+Brian have done their thing.

