## Spree 2.4.0 (unreleased) ##

* Spree no longer holds aws-sdk as a core dependency. In case you use it
  you need to add it to your Gemfile. See paperclip README for reference on
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

* Default ship and bill addresses are now saved and restored in callbacks. This
  makes the default address functionality available to orders driven through
  frontend, backend and API without duplicating the code.

    Magnus von Koeller

* When a user successfully uses a credit card to pay for an order, that card
  becomes the default credit card for that user. On future orders, we automatically
  add that default card as a payment when the order reaches the payment step.
    Magnus von Koeller

* Provided hooks for extensions to seamlessly integrate with the order population workflow.
  Extensions make use of the convention of passing parameters during the 'add to cart' 
  action https://github.com/spree/spree/blob/master/core/app/models/spree/order_populator.rb#L12
  with a prefix like [:options][:voucher_attributes] (in the case of the spree_vouchers 
  extension).  The extension then provides some methods named according to what was passed in 
  like:
  
  https://github.com/spree-contrib/spree_vouchers/blob/master/app/models/spree/order_decorator.rb#L51
  
  to determine if these possible line item customizations affect the line item equality condition and
  
  https://github.com/spree-contrib/spree_vouchers/blob/master/app/models/spree/variant_decorator.rb#L3
  
  to adjust a line item's price if necessary.
  
  https://github.com/spree/spree/blob/master/core/app/models/spree/order_contents.rb#L70
  shows how we expect inbound parameters (such as the voucher_attributes) to be saved in a 
  nested_attributes fashion.
  
    Jeff Squires
