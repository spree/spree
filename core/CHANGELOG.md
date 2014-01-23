## Spree 2.1.5 (unreleased) ##

* Variant#in_stock? with a quantity parameter is deprecated. Use Variant#can_stock? instead. The `in_stock?` method will be cached in Spree 2.2, and this caching would be made more complex with the quantity parameter. Typically, all users care about is whether or not the product is in stock, not typically if there's more than one of that product or not.

    Ryan Bigg
