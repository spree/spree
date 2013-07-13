---
title: "Adjustments"
section: core
---

## Overview

An adjustment in Spree tracks an adjustment to the price of an <%= link_to "Order", :orders %>, or an order's [Line Item](orders#line-items) within Spree.

Adjustments can be either positive or negative. Adjustments with a positive value are sometimes referred to as "charges" while adjustments with a negative value are sometimes referred to as "credits." These are just terms of convenience since there is only one `Spree::Adjustment` model in Spree which handles this by allowing either positive or negative values.

Adjustments have the following attributes:

* `amount` The dollar amount of the adjustment.
* `label`: The label for the adjustment to indicate what the adjustment is for.
* `mandatory`: Indicates if this adjustment is mandatory.
* `eligible`: Indicates if the adjustment is eligible for the thing it's adjusting.
* `state`: Can either be `open`, `closed`, or `finalized`. Once it is in the `finalized` state, it cannot be changed.

Along with these attributes, an adjustment links to three polymorphic objects:

* A source
* An adjustable
* An originator

The *source* is where an adjustment was triggered from. For tax and promotional adjustments, this will be the order itself. For shipping adjustments, this will be the shipment which corresponds with the shipping method for this order.

The *adjustable* is the object being adjusted, which is the order.

The *originator* is the object responsible for the adjustment. For promotional adjustments, this will be a `Spree::Promotion::Actions::CreateAdjustment` object. For tax adjustments, a `Spree::TaxRate` object. For shipping adjustments, a `Spree::ShippingMethod` object.

Adjustments can come from one of three locations:

* Tax Rates
* Shipping Methods
* Promotions

An adjustment's `label` attribute can be used as a good indicator of where the adjustment is coming from.

## Adjustment Scopes

There are some helper methods to return the different types of adjustments:

* `tax`: All adjustments where the originator is a `Spree::TaxRate` object.
* `shipping`: All adjustments where the originator is a `Spree::ShippingMethod` object.
* `promotion`: All adjustments where the originator is a `Spree::PromotionAction` object.
* `optional`: All adjustments which are not `mandatory`.
* `eligible`: Adjustments which have been determined to be `eligible` for their adjustable.
* `charge`: Adjustments which *increase* the price of their adjustable.
* `credit`: Adjustments which *decrease* the price of their adjustable.

These scopes can be called on either the `Spree::Adjustment` class itself, or on an `adjustments` association. For example, calling any one of these three is
valid:

```ruby
Spree::Adjustment.eligible
order.adjustments.eligible
line_item.adjustments.eligible```