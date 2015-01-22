---
title: "Adjustments"
section: core
---

## Overview

An `Adjustment` object tracks an adjustment to the price of an [Order](orders), an order's [Line Item](orders#line-items), or an order's [Shipments](shipments) within a Spree Commerce storefront.

Adjustments can be either positive or negative. Adjustments with a positive value are sometimes referred to as "charges" while adjustments with a negative value are sometimes referred to as "credits." These are just terms of convenience since there is only one `Spree::Adjustment` model in a storefront which handles this by allowing either positive or negative values.

Adjustments can either be considered included or additional. An "included" adjustment is an adjustment to the price of an item which is included in that price of an item. A good example of this is a GST/VAT tax. An "additional" adjustment is an adjustment to the price of the item on top of the original item price. A good example of that would be how sales tax is handled in countries like the United States.

Adjustments have the following attributes:

* `amount` The dollar amount of the adjustment.
* `label`: The label for the adjustment to indicate what the adjustment is for.
* `eligible`: Indicates if the adjustment is eligible for the thing it's adjusting.
* `mandatory`: Indicates if this adjustment is mandatory; i.e that this adjustment *must* be applied regardless of its eligibility rules.
* `state`: Can either be `open`, `closed`, or `finalized`. Once it is in the `finalized` state, it cannot be changed.
* `included`: Whether or not this adjustment affects the final price of the item it is applied to. Used only for tax adjustments which may themselves be included in the price.

Along with these attributes, an adjustment links to three polymorphic objects:

* A source
* An adjustable

The *source* is the source of the adjustment. Typically a `Spree::TaxRate` object or a `Spree::PromotionAction` object.

The *adjustable* is the object being adjusted, which is either an order, line item or shipment.

Adjustments can come from one of two locations:

* Tax Rates
* Promotions

An adjustment's `label` attribute can be used as a good indicator of where the adjustment is coming from.

## Adjustment Scopes

There are some helper methods to return the different types of adjustments:

```ruby
scope :shipping, -> { where(adjustable_type: 'Spree::Shipment') }
scope :is_included, -> { where(included: true)  }
scope :additional, -> { where(included: false) }
```

* `open`: All open adjustments.
* `eligible`: All eligible adjustments for the order. Useful for determining which adjustments are applying to the adjustable.
* `tax`: All adjustments which have a source that is a `Spree::TaxRate` object
* `price`: All adjustments which adjust a `Spree::LineItem` object.
* `shipping`: All adjustments which adjust a `Spree::Shipment` object.
* `promotion`: All adjustments where the source is a `Spree::PromotionAction` object.
* `optional`: All adjustments which are not `mandatory`.
* `return_authorization`: All adjustments where the source is a `Spree::ReturnAuthorization`.
* `eligible`: Adjustments which have been determined to be `eligible` for their adjustable.
* `charge`: Adjustments which *increase* the price of their adjustable.
* `credit`: Adjustments which *decrease* the price of their adjustable.
* `optional`: Adjustments which are not mandatory.
* `included`: Adjustments which are included in the object's price. Typically tax adjustments.
* `additional`: Adjustments which modify the object's price. The default for all adjustments.

These scopes can be called on either the `Spree::Adjustment` class itself, or on an `adjustments` association. For example, calling any one of these three is
valid:

```ruby
Spree::Adjustment.eligible
order.adjustments.eligible
line_item.adjustments.eligible
shipment.adjustments.eligible
```

## Adjustment Associations

As of Spree 2.2, you are able to retrieve the specific adjustments of an Order, a Line Item or a Shipment.

An order itself, much like line items and shipments, can have its own individual modifications. For instance, an order with over $100 of line items may have 10% off. To retrieve these adjustments on the order, call the `adjustments` association:

```ruby
order.adjustments
```

If you want to retrieve all the adjustments for all the line items, shipments and the order itself, call the `all_adjustments` method:

```ruby
order.all_adjustments
```

If you want to grab just the line item adjustments, call `line_item_adjustments`:

```ruby
order.line_item_adjustments
```

Simiarly, if you want to grab the adjustments applied to shipments, call `shipment_adjustments`:

```ruby
order.shipment_adjustments
```
