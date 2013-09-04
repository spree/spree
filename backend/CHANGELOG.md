## Spree 2.0.1 (unreleased) ##

*   Symbolize attachment style keys on ImageSettingController otherwise users
    would get *undefined method `processors' for "48x48>":String>* since
    paperclip can't handle key strings.

    *Washington Luiz*

* Fix bug where taxonomy URL was incorrect when Spree was mounted at a non-root path 50ac165c13f6d9123db704b72e9feae86971af70.

    *Washington Luiz*

* Fixed issue where selecting an existing user in the customer details step would not associate them with an order.
    
<<<<<<< HEAD
    *Ryan Bigg and dan-ding"
=======
    *Ryan Bigg and dan-ding*

*   We now use [jQuery.payment](https://stripe.com/blog/jquery-payment) (from Stripe) to provide slightly better formatting on credit card number, expiry and CVV fields.

    *Ryan Bigg*

*   "Infinite scrolling" now implemented for products taxon search to prevent loading all taxons at once. Only 50 taxons are loaded at a time now.
    
    *Ryan Bigg*
>>>>>>> 01943b1... [api] Implement pagination for taxons#index route
