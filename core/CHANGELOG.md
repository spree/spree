## Spree 2.0.6 ##

* Fix admin menu not icons not being centered. #3725

    *Ramon Roche*

* Payment identifiers now do not change on each save. #3733

    *Ryan Bigg*

* Added migrations to make the migration from Spree 1.3.x to 2.0.x a little easier. #3605 #3660

    *Stefan Wrobel*

* Product#stock_items now returns stock items for the master variant as well. #3737

    *Ryan Bigg*

* Add inventory_units association back to the Order model. #3744

    *Ryan Bigg*

* Bump Activemerchant to 1.39.2.

    *Ryan Bigg*

* Fix issue where cart.png was not being dealt with correctly during precompilation.

    *Ryan Bigg*

* StockItem#process_backorders now processes backorders when the stock is adjusted postively. #3755

    *Ryan Bigg*

* Fixed issue where shipping rates would lose the current selected rate when refreshing rates. #3766

    *dan-ding*

* Fixed issue where force_non_ssl_redirect redirect location was like `/orders/populate?controller=home.`, rather than just `/`. #3799

    *John Hawthorn*

* Fixed sample data loading issues with shipping methods. #3776

    *Washington Luiz*

* Removed unused credit card fields, start_month, start_year and issue_number. #3802

    *John Hawthorn*

* Fixed issue where a product could be linked to a taxon more than once. #3494

    *Ryan Bigg*

* Included jquery.validate locale messages when the locale is not "en" #3794

    *Ryan Bigg*

* Fixed issue where stock items could not be created if a deleted stock item for that variant existed already. #3834

    *Washington Luiz*

* Removed force_ssl_redirect, as Rails 3.2.14 and Rails 4 both have this available.

    *Washington Luiz*

* Fixed redirect loop with redirect_https_to_http. #3813

    *John Hawthorn*

* Use sRGB colorspace in Image model. Using the RGB colorspace on more recent versions of ImageMagick cause the image to be uploaded darker. Caveat: Using sRGB on older versions of ImageMagick may also cause this bug. If you're seeing images being uploaded darker after this change, please upgrade your ImageMagick version.

    *Ryan Bigg*

* Fixed issue where not including frontend component may have caused the `preference_rescue.rb` that a migration depends on to go missing. #3860


## Spree 2.0.x ##

*  Sandbox generator and installer now use the correct 2-0-stable branch of spree_auth_devise 
3179a7ac85d4cfcb76622509fc739a0e17668d5a & 759fa3475f5230da3794aed86503913978dde22d.

* Product requires `shipping_category_id` on create #3188.

    *Jeff Dutil*

*   No longer set ActiveRecord::Base.include_root_in_json = true during install.
    Originally set to false back in 2011 according to convention. After
    https://groups.google.com/forum/#!topic/spree-user/D9dZQayC4z, it
    was changed. Applications should now decide their own setting for this value.

    *John Dyer and Sean Schofield*

* Revert bump of Rubygems required version which made Spree 2.0.0 unusable on Heroku. 77103dc4f4c93c195ae20f47944f68ef31a7bbe9

    *@Actven*

* Improve performance of `Order#payment_required?` by not updating the totals every time. #3040 #3086

    *Washington Luiz*

* Remove after_save callback for stock items backorders processing and
    fixes count on hand updates when there are backordered units #3066

    *Washington Luiz*

* InventoryUnit#backordered_for_stock_item no longer returns readonly objects
    neither return an ActiveRecored::Association. It returns only an array of
    writable backordered units for a given stock item #3066

    *Washington Luiz*

* Scope shipping rates as per shipping method display_on #3119
    e.g. Shipping methods set to back_end only should not be displayed on frontend too

   *Washington Luiz*

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

*   Change `order.promotion_credit_exists?` api. Now it receives an adjustment
    originator (PromotionAction instance) instead of a promotion. Allowing
    multiple adjustments being created for the same promotion as the current
    PromotionAction / Promotion api suggests #3262

    * Washington Luiz *

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