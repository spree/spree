## Spree 2.1.2 ##

* References to cart.png will now reference the precompiled asset.

    *Dan Kubb*

* Special instructions are no longer ignored when specified in the checkout.

    *Dan Kubb*

* Use `display_price` more consistently. #3822

* When a payment fails, it will now include the message from the gateway as a validation error. This potentially provides additional information to the user, which may guide them to correcting the data they're inputting, allowing the payment to go through successfully. #3851

    *Ryan Bigg*

## Spree 2.1.0 ##

*  Fix issue where "Use Billing Address" checkbox was unticked when certain
   browsers autocompleted the checkout form. #3068 #3085

   *Washington Luiz*

*  Switch to new Google Analytics analytics.js SDK from ga.js SDK for custom dimensions & metrics.

   *Jeff Dutil*

*  We now use [jQuery.payment](https://stripe.com/blog/jquery-payment) (from Stripe) to provide slightly better formatting on credit card number, expiry and CVV fields.

   *Ryan Bigg*