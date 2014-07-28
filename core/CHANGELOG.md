## Spree 2.4.0 (unreleased) ##

* Added Spree::Config.capture_on_dispatch that when set to true will
  cause shipments to advance to ready state upon successfully authorizing
  payment for the order.  As each shipment is marked shipped the
  shipment's total will be captured from the authorization. Fixes #4727

     Jeff Dutil

* Added `actionable?` for Spree::Promotion::Rule. `actionable?` defines
  if a promotion action can be applied to a specific line item. This
  can be used to customize which line items can accept a promotion
  action by defining its logic within the promotion rule rather than
  relying on Spree's default behaviour. Fixes #5036

    Gregor MacDougall
