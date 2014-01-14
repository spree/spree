## Spree 2.0.8 (unreleased) ##

* Bumped Rails to 3.2.16

    Ryan Bigg

* Bumped ActiveMerchant to 1.42.3

    Ryan Bigg

* Bumped aws-sdk to 1.31.3.

    Ryan Bigg

* Bumped to ransack 1.1.0.

    Ryan Bigg

* Bumped Kaminari to 0.15.0.

    Ryan Bigg

* Add `currency_sign_before_symbol` setting, allows for either -$10.00 or $-10.00.

    Ryan Bigg

* Switched from `* 100` to `money.cents` in a couple of places in `Payment::Processing`, for proper handling of cents in currencies where cents are not 100ths of a dollar. 

    Clarke Brunsdon

* Spree.user_class now accepts a Symbol, as well as a String.

    hbakhtiyor

* All adjustments are now updated during `Order#update!`.  #3960

    John Hawthorn

* Can now control whether or not variants have inventory tracking on a per-variant basis. #3974

    Michael Tucker

* Cancelling an order now sets the `payment_state` to `credit_owed` in all cases. #3711

    Ryan Bigg

* Only on hand inventory units are now restocked. 
  
    Washington Luiz

* Shipment numbers are now once again 12 characters long (H, followed by 11 numbers). #4063

    Ryan Bigg

* Inferring a currency for `Spree::Money.parse` when none is given now works. #4077

    cheef

* The User promotion rule should now no longer use the `Spree.user_class` class as its association. 6fd78ec

    Peter Berkenbosch

* Only eligible promotions are now counted towards `Promotion#credits`. #4120

    Ryan Bigg

* Order#available_payment_methods will now return payment methods marked as 'Both' #4199

    Francisco Trindade & Ryan Bigg