## Spree 2.1.0 ##

*  Fix issue where "Use Billing Address" checkbox was unticked when certain
   browsers autocompleted the checkout form. #3068 #3085

   *Washington Luiz*

*  Switch to new Google Analytics analytics.js SDK from ga.js SDK for custom dimensions & metrics.

   *Jeff Dutil*

*  We now use [jQuery.payment](https://stripe.com/blog/jquery-payment) (from Stripe) to provide slightly better formatting on credit card number, expiry and CVV fields.

   *Ryan Bigg*