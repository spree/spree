## Spree 2.0.6 ##


* Use default datepicker format is used if none is specified in the locale file. #3602

    *Peter Goldstein*

* Added the ability to change a payment's amount through the backend. #3765

    *Dan Kubb*

* Fixed issue where promotion rules select box was not being reloaded correctly. #3572 #3816

    *Washington Luiz*

* Prices are now displayed in the local format on products/new.

    *laurens*

* Change authorize_admin to use the controller's name, rather than `Object` when `model_class` does not return anything. #3622

    *Ryan Bigg*

* Fixed issue where cancelling a line item delete didn't actually cancel it. #3862

    *Ryan Bigg*

* Fixed slow loading of "Add Stock Movement" screen if there were a lot of variants in the system.
    
    *Ryan Bigg*

 
## Spree 2.0.x ##

*   Symbolize attachment style keys on ImageSettingController otherwise users
    would get *undefined method `processors' for "48x48>":String>* since
    paperclip can't handle key strings.

    *Washington Luiz*

* Fix bug where taxonomy URL was incorrect when Spree was mounted at a non-root path 50ac165c13f6d9123db704b72e9feae86971af70.

    *Washington Luiz*

* Fixed issue where selecting an existing user in the customer details step would not associate them with an order.
    
    *Ryan Bigg and dan-ding*

*   We now use [jQuery.payment](https://stripe.com/blog/jquery-payment) (from Stripe) to provide slightly better formatting on credit card number, expiry and CVV fields.

    *Ryan Bigg*

*   "Infinite scrolling" now implemented for products taxon search to prevent loading all taxons at once. Only 50 taxons are loaded at a time now.
    
    *Ryan Bigg*
