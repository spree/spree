## Spree 2.1.0 (unreleased) ##

*   layouts/admin.html.erb was broken into partials for each section. e.g.
    header, menu, submenu, sidebar. Extensions should update their deface
    overrides accordingly

    *Washington Luiz*

*   No longer requires all jquery ui modules. Extensions should include the
    ones they need on their own manifest file. #3237

    *Washington Luiz*
    
*   Symbolize attachment style keys on ImageSettingController otherwise users
    would get *undefined method `processors' for "48x48>":String>* since
    paperclip can't handle key strings. #3069 #3080

    *Washington Luiz*

*   Split line items across shipments. Use this to move line items between 
    existing shipments or to create a new shipment on an order from existing
    line items.

    *John Dyer*

*   Fixed display of "Total" price for a line item on a shipment. #3135

    *John Dyer*

*   Fixed issue where selecting an existing user in the customer details step would not associate them with an order.
    
    *Ryan Bigg and dan-ding*

*   We now use [jQuery.payment](https://stripe.com/blog/jquery-payment) (from Stripe) to provide slightly better formatting on credit card number, expiry and CVV fields.

    *Ryan Bigg*

*   "Infinite scrolling" now implemented for products taxon search to prevent loading all taxons at once. Only 50 taxons are loaded at a time now.
    
    *Ryan Bigg*
