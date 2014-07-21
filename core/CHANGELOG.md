## Spree 2.4.0 (unreleased) ##

* Added Spree::Config.capture_on_dispatch that when set to true will
  cause shipments to advance to ready state upon successfully authorizing
  payment for the order.  As each shipment is marked shipped the
  shipment's total will be captured from the authorization. Fixes #4727

     Jeff Dutil
