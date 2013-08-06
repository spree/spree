## Spree 2.1.0 (unreleased) ##

* Product requires `shipping_category_id` on create #3188.

    *Jeff Dutil*

*   No longer set ActiveRecord::Base.include_root_in_json = true during install.
    Originally set to false back in 2011 according to convention. After
    https://groups.google.com/forum/#!topic/spree-user/D9dZQayC4z, it
    was changed. Applications should now decide their own setting for this value.

    *Weston Platter*
    
*   Change `order.promotion_credit_exists?` api. Now it receives an adjustment
    originator (PromotionAction instance) instead of a promotion. Allowing
    multiple adjustments being created for the same promotion as the current
    PromotionAction / Promotion api suggests #3262

*   Remove after_save callback for stock items backorders processing and
    fixes count on hand updates when there are backordered units #3066

    *Washington Luiz*

*   InventoryUnit#backordered_for_stock_item no longer returns readonly objects
    neither return an ActiveRecored::Association. It returns only an array of
    writable backordered units for a given stock item #3066

    *Washington Luiz*

*   Scope shipping rates as per shipping method display_on #3119
    e.g. Shipping methods set to back_end only should not be displayed on frontend too

    *Washington Luiz*

*   Add `propagate_all_variants` attribute to StockLocation. It controls
    whether a stock items should be created fot the stock location every time
    a variant or a stock location is created

    *Washington Luiz*

*   Add `backorderable_default` attribute to StockLocation. It sets the
    backorderable attribute of each new stock item

    *Washington Luiz*

*   Removed `t()` override in `Spree::BaseHelper`. #3083

    *Washington Luiz*

*   Improve performance of `Order#payment_required?` by not updating the totals every time. #3040 #3086

    *Washington Luiz*

*   Fixed the FlexiRate Calculator for cases when max_items is set. #3159

    *Dana Jones*

* Translation for admin tabs are now located under the `spree.admin.tab` key. Previously, they were on the top-level, which lead to conflicts when users wanted to override view translations, like this:

```yml
en:
  spree:
    orders:
      show:
        thank_you: "Thanks, buddy!"
```

See #3133 for more information.

    * Ryan Bigg*

* CreditCard model now validates that the card is not expired.

    *Ryan Bigg*

* Payment model will now no longer provide a vague error message for when the source is invalid. Instead, it will provide error messages like "Credit Card Number can't be blank"

    *Ryan Bigg*

* Calling #destroy on any PaymentMethod, Product, TaxCategory, TaxRate or Variant object will now no longer delete that object. Instead, the `deleted_at` attribute on that object will be set to the current time. Attempting to find that object again using something such as `Spree::Product.find(1)` will fail because there is now a default scope to only find *non*-deleted records on these models. To remove this scope, use `Spree::Product.unscoped.find(1)`. #3321

    *Ryan Bigg*

* Removed `variants_including_master_and_deleted`, in favour of using the Paranoia gem. This scope would now be achieved using `variants_including_master.with_deleted`.

    *Ryan Bigg*

* You can now find the total amount on hand of a variant by calling `Variant#total_on_hand`. #3427

    *Ruben Ascencio*

* Tax categories are now stored on line items. This should make tax calculations slightly faster. #3481

    *Ryan Bigg*