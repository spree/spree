## Spree 2.1.0 (unreleased) ##

* The Products API endpoint now returns an additional key called `display_price`, which is the proper rendering of the price of a product.

    *Ryan Bigg*

* The Images API's `attachment_url` key has been removed in favour of keys that reflect the current image styles available in the application, such as `mini_url` and `product_url`. Use these now to references images.

    *Ryan Bigg*

* Fix issue where calling OrdersController#update with line item parameters would *always* create new line items, rather than updating existing ones.

    *Ryan Bigg*

* The Orders API endpoint now returns an additional key called `display_item_total`, which is the proper rendering of the total line item price of an order.

    *Ryan Bigg*

* All API responses now contain a `Cache-Control` header.

    *Ryan Bigg*

* Include a `per_page` key in Products API end response so that libraries like jQuery.simplePagination can use this to display a pagination element on the page.

    * Ryan Bigg*

* Line item responses now contain `single_display_amount` and `display_amount` for "pretty" versions of the single and total amount for a line item, as well as a `total` node which is an "ugly" version of the total amount of a line item.

    * Ryan Bigg

* /api/orders endpoints now accept a `?order_token` parameter which should be the order's token. This can be used to authorize actions on an order without having to pass in an API key.

    * Ryan Bigg