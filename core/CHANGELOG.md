## Spree 2.2.0 (unreleased) ##

### Major

#### Adjustments Refactoring

#### Asset renaming

An issue was brought up in #4050 where a user showed us that a `require_tree` use inside `app/assets` would also require the Spree assets that were placed in `app/assets/store` and app/assets/admin` respectively. This would happen in areas of the application where Spree wasn't even used.

To fix this bug, we have moved the location of the assets to `vendor/assets`. Frontend's assets are now placed in `vendor/assets/spree/frontend` and Backend's are in `vendor/assets/spree/backend`. 

Similar changes to this have also been made to extensions, where their assets are now placed in `app/assets/spree/[extension_name]`. Ultimately, these changes fix the bug and now we're using the same names to refer to the same components (store -> frontend, admin -> backend) on assets as we do internally to Spree.

*Ryan Bigg*

### Minor

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
