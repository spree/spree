---
title: "Shipments"
---

## Overview

Shipments within Spree tie to <%= link_to "Orders", :orders %>, and are used to
track shipping information regarding the items for that order. Shipments also
depend on <%= link_to "Calculators", :calculators %>.

TODO: Tie in to inventory here as well.

## How shipments are displayed

There are four checks that a shipment goes through to determine if it is
available for an order:

* Is the shipment available for this order?
* Is the shipment within the same zone as the order?
* Do the shipping categories of this shipment and this order's products match?
* Do the currencies of the shipment's calculator and the order match?

If the answer to all four of these questions is "yes", then a shipping method
will be displayed to the user for selection.

***
  If no shipping methods match at all, a user will not be able to proceed past the
  address step of the checkout.
***

### Is this shipment available?

This first check is rather simple.

The shipment asks its calculator if the
calculator is available for this object. By default,
`Spree::Calculator#available?` returns `true`, and so this will always be true
for all orders. That is, unless you define a calculator which <%= link_to "overrides
`available?` to do something different", LINKS[:calculators] + "#determining-availability" %>

### Within the same zone?

Every shipping method can link to a `Zone` object. This check just checks to see
if the zone is set for the shipping method and if so then checks if the order's
shipping address is within that zone.

### Shipping categories match?

A shipping method can be tied to a shipping category, which itself can be tied
to many products. If a shipping category is selected for a shipping method, then
a check is done depending on the type of match that is selected. There are three
types of matching: all, one, or none.

An "all" match is when all products of an order has to have the same shipping
category as the shipping method.

The "one" match type is when only one product of an order has to have the same
shipping category.

The "none" match type is when no products of an order match the shipping
category of the shipping method.

### Currencies match?

This check is simple as well. If a shipping method's calculator's currency
matches the currency of the order, then the shipping method will be valid for
this order.

***
  An order's currency is determined by the `Spree::Config[:currency]`
  value at the time of an order's creation.
***


