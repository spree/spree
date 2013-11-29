## Spree 2.2.0 (unreleased) ##

*   Add a `name` column to spree_payments. That should hold the *Name on card*
    option in payment checkout step.

    Washington Luiz

*   Associate line item and inventory units for better extensibility with
    product assemblies. Migration was added to set line_item_id for existing
    inventory units.

*   A *channel* column was added to the spree_orders table. Users can set
    it when importing orders from other stores. e.g. amazon

    Washington Luiz

*   Introduce `Core::UserAddress` module. Once included on the store user class
    the user address can be rememembered on checkout

    Washington Luiz

* Added tax_category to variants, to allow for different variants of a product to have different tax categories. #3946
