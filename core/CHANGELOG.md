## Spree 2.1.0 (unreleased) ##

*   Add `propagate_all_variants` attribute to StockLocation. It controls
    whether a stock items should be created fot the stock location every time
    a variant or a stock location is created

    *Washington Luiz*

*   Add `backorderable_default` attribute to StockLocation. It sets the
    backorderable attribute of each new stock item

    *Washington Luiz*

*   Removed `t()` override in `Spree::BaseHelper`. #3083

    *Washington Luiz*