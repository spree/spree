## Spree 2.2.0 (unreleased) ##

### Major

#### Adjustments Refactoring

The adjustments system in Spree has undergone a large portion of work. Adjustments (typically originating from promotions and taxes) can now be applied at a line item, shipment or order level.

**This system has been designed to be backwards-compatible with older versions of Spree, so that an upgrade path is relatively easy. If you encounter any issues during an upgrade, please [file an issue](https://github.com/spree/spree/issues/new).**

Along with this, taxes are now split into two groupings: "additional" and "included". Additional taxes are those which increase the price of the item they're attached to. Included taxes are those which are already included in the cost of the item. It is still necessary to track these included taxes due to tax reporting requirements in many countries.

Shipments no longer have a linked adjustment. Instead, the shipment itself has a "cost" attribute which is used in the calculation of shipping costs for an order.

Also worth noting is that the number of callbacks triggered when any aspect of an order is updated has been greatly reduced, which should lead up to speed-ups in stores. An example of this would be in prior versions of Spree, an order would trigger an update on all its adjustments when it updated. With the new system, only line items or shipments that change will have their adjustments updated. 

For more information about this, [Ryan Bigg wrote up a long explanation about it](http://ryanbigg.com/2013/09/order-adjustments/), and there is further discussion on #3567. 

#### Asset renaming

An issue was brought up in #4050 where a user showed us that a `require_tree` use inside `app/assets` would also require the Spree assets that were placed in `app/assets/store` and app/assets/admin` respectively. This would happen in areas of the application where Spree wasn't even used.

To fix this bug, we have moved the location of the assets to `vendor/assets`. Frontend's assets are now placed in `vendor/assets/spree/frontend` and Backend's are in `vendor/assets/spree/backend`. 

Similar changes to this have also been made to extensions, where their assets are now placed in `app/assets/spree/[extension_name]`. Ultimately, these changes fix the bug and now we're using the same names to refer to the same components (store -> frontend, admin -> backend) on assets as we do internally to Spree.

You will need to manually rename asset requires within your application:

* `admin/spree_backend` => `spree/backend`
* `store/spree_frontend` => spree/frontend`

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

    Peter Rhoades

*   Removed `Spree::Activator`. Promotions are now activated using the `Spree::PromotionHandler` classes.

    Ryan Bigg

*   Promotion#event_name attribute has been removed. A promotion's event now depends on the fields that are filled out during its creation.

    Ryan Bigg

*   Simplified OrderPopulator to take only a variant_id and a quantity, rather than a confusing hash of product/variant ids.

    Ryan Bigg  
