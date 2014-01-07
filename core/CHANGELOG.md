## Spree 2.1.4 (unreleased) ##

* Introduce Core::UserAddress module. Once included on the store user class the user address can be rememembered on checkout

    Washington Luiz / Peter Berkenbosch

* Fixed issue where selecting a payment method that required confirmation would fail, then another payment method that did *not* require confirmation was then chosen, but confirmation step would still appear. #3970

    Washington Luiz

* Bumped Kaminari version to 0.15.0

    Ryan Bigg

* Shipments are now "touched" when Inventory Units are updated, and Orders are now "touched" when Payments are updated. Variants are now "touched" when Stock Items are updated. This "touching" will update the record's timestamp.
  
    Ryan Bigg

* If a name field now exists on spree_variants, Spree will use that rather than the virtual attribute defined by `delegates_belongs_to`. #4012

    Washington Luiz

* Moved `Money.extract_cents` and `Money.parse` to `Spree::Money`, as those methods are being deprecated in the Money gem, but Spree still uses them to a great extent.

    Ryan Bigg

* Added ability to enable/disable inventory tracking control on the variant-level.

    Michael Tucker

* Only in_stock inventory units are now restocked once an order is canceled.

    Washington Luiz

* Backorders for incomplete orders are now no longer fufiled. #4056

    Sean O'Hara

* Shipment numbers should be 11-characters, not 9. #4063

    Ryan Bigg

* Only available shipping rates are now sorted in `Spree::Stock::Estimator`. #4067

    Ryan Bigg

* Email is now only required once past the address step of the checkout. #4079

    Ryan Bigg

* Ensure state_changes records are no longer created if the state changes. #4072

    Ryan Bigg

* `allow_ssl_in_*` variables are no longer accessed during initialization. #4094

    John Hawthorn

* Promotion rules are now loaded after initialization so that the user rule is loaded correctly. 

    Peter Berkenbosch

* Fixed issue where common shipping methods were not being returned when calculating packages. #4102

    Dan Kubb

* Only eligible promotions now count towards `credits_count` on `Spree::Promotion` objects. #4120

    Ryan Bigg



