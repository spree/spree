## Spree 2.1.0 (unreleased) ##

* The Products API endpoint now returns an additional key called `shipping_category_id`, and also requires `shipping_category_id` on create.

    *Jeff Dutil*

* The Products API endpoint now returns an additional key called `display_price`, which is the proper rendering of the price of a product.

    *Ryan Bigg*

* The Images API's `attachment_url` key has been removed in favour of keys that reflect the current image styles available in the application, such as `mini_url` and `product_url`. Use these now to references images.

    *Ryan Bigg*

* Fix issue where calling OrdersController#update with line item parameters would *always* create new line items, rather than updating existing ones.

    *Ryan Bigg*

* The Orders API endpoint now returns an additional key called `display_item_total`, which is the proper rendering of the total line item price of an order.

    *Ryan Bigg*

* Include a `per_page` key in Products API end response so that libraries like jQuery.simplePagination can use this to display a pagination element on the page.

    *Ryan Bigg*

* Line item responses now contain `single_display_amount` and `display_amount` for "pretty" versions of the single and total amount for a line item, as well as a `total` node which is an "ugly" version of the total amount of a line item.

    *Ryan Bigg*

* /api/orders endpoints now accept a `?order_token` parameter which should be the order's token. This can be used to authorize actions on an order without having to pass in an API key.

    *Ryan Bigg*

* Requests to POST /api/line_items will now update existing line items. For example if you have a line item with a variant ID=2 and quantity=10 and you attempt to create a new line item for the same variant with a quantity of 5, the existing line item's quantity will be updated to 15. Previously, a new line item would erroneously be created.

    *Ryan Bigg*

* /api/countries now will a 304 response if no country has been changed since the last request.

    *Ryan Bigg*

* The Shipments API no longer returns inventory units. Instead, it will return manifest objects. This is necessary due to the split shipments changes brought in by Spree 2.

    *Ryan Bigg*

* Checkouts API's update action will now correctly process line item attributes (either `line_items` or `line_item_attributes`)

    *Ryan Bigg*

* The structure of shipments data in the API has changed. Shipments can now have many shipping methods, shipping rates (which in turn have many zones and shipping categories), as well as a new key called "manifest" which returns the list of items contained within just this shipment for the order.

    *Ryan Bigg*

* Address responses now contain a `full_name` attribute.

    *Ryan Bigg*

* Shipments responses now contain a `selected_shipping_rate` key, so that you don't have to sort through the list of `shipping_rates` to get the selected one.

    *Ryan Bigg*

* Checkouts API now correctly processes incoming payment data during the payment step.

    *Ryan Bigg*

* Fix issue where `set_current_order` before filter would be called when CheckoutsController actions were run, causing the order object to be deleted. #3306

    *Ryan Bigg*

* An order can no longer transition past the "cart" state without first having a line item. #3312

    *Ryan Bigg*

* Attributes other than "quantity" and "variant_id" will be added to a line item when creating along with an order. #3404

    *Alex Marles & Ryan Bigg*

* Requests to POST /api/line_items will now update existing line items. For example if you have a line item with a variant ID=2 and quantity=10 and you attempt to create a new line item for the same variant with a quantity of 5, the existing line item's quantity will be updated to 15. Previously, a new line item would erroneously be created.

    * Ryan Bigg

* Checkouts API's update action will now correctly process line item attributes (either `line_items` or `line_item_attributes`)

    * Ryan Bigg

* Taxon attributes from `/api/taxons` are now returned within `taxons` subkey. Before:

```json
[{ name: 'Ruby' ... }]
```

Now:

```json
{ taxons: [{ name: 'Ruby' }]}
```

    * Ryan Bigg