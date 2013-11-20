## Spree 2.1.3 ##

*   A *channel* column was added to the spree_orders table. Users can set
    it when importing orders from other stores. e.g. amazon

    Washington Luiz

*   Highline version has been bumped to allow anything > 1.6.18 and < 1.7.x.
    
    Ryan Bigg

*   Active Merchant version has been bumped to 1.42.0. This should fix Money gem dependency problems.

    Ryan Bigg

*   aws-sdk version has been bumped to 1.27.0. This should fix Nokogiri gem dependency problems.

    Ryan Bigg

*   Fixed issue where Product#set_property was causing an undefined method when spree_i18n was in use.

    Ryan Bigg

*   Taxes can now be classed as "included" or "additional". Taxes which are "included" are those such as VAT/GST, where the price includes the tax already. "Additional" taxes are like Sales Tax in the US where the tax amount is added on after the listed price of the item. This change now means that included taxes are displayed on the checkout.

    Ryan Bigg