## Spree 2.4.0 (unreleased) ##

* Spree no longer holds aws-sdk as a core dependency. In case you use it
  you need to add it to your Gemfile. See paperplip README for reference on
  scenarios where this is needed https://github.com/thoughtbot/paperclip/tree/v4.1.1#understanding-storage

    Washigton L Braga Jr

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

* Refactored Stock::Coordinator to optionally accept a list of inventory units 
  for an order so that shipments can be created for an order that do not comprise
  only of the order's line items.

     Andrew Thal
