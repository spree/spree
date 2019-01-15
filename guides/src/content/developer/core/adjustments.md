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
* `state`: Can either be `open` or `closed`. Once an adjustment is closed, it will not be automatically updated.
* `included`: Whether or not this adjustment affects the final price of the item it is applied to. Used only for tax adjustments which may themselves be included in the price.

Along with these attributes, an adjustment links to three polymorphic objects:

* A source
* An adjustable

The *source* is the source of the adjustment. Typically a `Spree::TaxRate` object or a `Spree::PromotionAction` object.

The *adjustable* is the object being adjusted, which is either an order, line item or shipment.

Adjustments can come from one of two locations within Spree's core:

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
* `tax`: All adjustments which have a source that is a `Spree::TaxRate` object
* `price`: All adjustments which adjust a `Spree::LineItem` object.
* `shipping`: All adjustments which adjust a `Spree::Shipment` object.
* `promotion`: All adjustments where the source is a `Spree::PromotionAction` object.
* `optional`: All adjustments which are not `mandatory`.
* `return_authorization`: All adjustments where the source is a `Spree::ReturnAuthorization`.
* `eligible`: Adjustments which have been determined to be `eligible` for their adjustable. Useful for determining which adjustments are applying to the adjustable.
* `charge`: Adjustments which *increase* the price of their adjustable.
* `credit`: Adjustments which *decrease* the price of their adjustable.
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

## Extending Adjustments

### Creating a New Adjuster

To create a new adjuster for Spree, create a new ruby object that inherits from `Spree::Adjustable::Adjuster::Base` and implements an `update` method:

```ruby
module Spree
  module Adjustable
    module Adjuster
      class MyAdjuster < Spree::Adjustable::Adjuster::Base
        def update
          ...
          #your ruby magic
          ...
          update_totals(some_total, my_other_total)
        end

        private

        # Note to persist your totals you need to update @totals
        # This is shown in a separate method for readability
        def update_totals(some_total, my_other_total)
          # if you want to keep track of your total, 
          # you will need the column defined
          @totals[:total_you_want_to_track] += some_total
          @totals[:taxable_adjustment_total] += some_total
          @totals[:non_taxable_adjustment_total] += my_other_total
        end
      end
    end
  end
end
```

Next you need to add the class to spree `Rails.application.config.spree.adjusters` so it is included whenever adjustments are updated (Promotion and Tax are included by default):

```ruby
# NOTE: it is advisable that that Tax be implemented last so Tax is calculated correctly
app.config.spree.adjusters = [
          Spree::Adjustable::Adjuster::MyAdjuster,
          Spree::Adjustable::Adjuster::Promotion,
          Spree::Adjustable::Adjuster::Tax
          ]
```

That's it! Your custom adjuster is ready to go.
