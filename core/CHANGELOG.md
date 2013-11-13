## Spree 2.2.0 (unreleased) ##

*   A *channel* column was added to the spree_orders table. Users can set
    it when importing orders from other stores. e.g. amazon

    Washington Luiz

*   Introduce `Core::UserAddress` module. Once included on the store user class
    the user address can be rememembered on checkout

    Washington Luiz

* Added tax_category to variants, to allow for different variants of a product to have different tax categories. #3946