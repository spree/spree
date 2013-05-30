## Spree 2.1.0 (unreleased) ##

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
