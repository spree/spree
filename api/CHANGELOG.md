## Spree 2.1.0 (unreleased) ##

* The Products API endpoint now returns an additional key called `display_price`, which is the proper rendering of the price of a product.

    *Ryan Bigg*

* The Images API's `attachment_url` key has been removed in favour of keys that reflect the current image styles available in the application, such as `mini_url` and `product_url`. Use these now to references images.

    *Ryan Bigg*

* Fix issue where calling OrdersController#update with line item parameters would *always* create new line items, rather than updating existing ones.

    *Ryan Bigg*