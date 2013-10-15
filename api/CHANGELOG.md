## Spree 2.0.6 ##

* Normal users can no longer read stock item, stock location or stock movements API endpoints.

  *Ryan Bigg*
  
## Spree 2.0.x ##

* PUT requests to Checkouts API endpoints now require authorization to alter an order.

    *Ryan Bigg*

* The Products API endpoint now returns an additional key called `shipping_category_id`, and also requires `shipping_category_id` on create.

    *Jeff Dutil*

* Checkouts API's update action will now correctly process line item attributes (either `line_items` or `line_item_attributes`)

    * Ryan Bigg*

* Checkouts API now correctly processes incoming payment data during the payment step.

    *Ryan Bigg*

* Fix issue where `set_current_order` before filter would be called when CheckoutsController actions were run, causing the order object to be deleted. #3306

    *Ryan Bigg*

* An order can no longer transition past the "cart" state without first having a line item. #3312

    *Ryan Bigg*

* Attributes other than "quantity" and "variant_id" will be added to a line item when creating along with an order. #3404

    *Alex Marles & Ryan Bigg* 

* Taxon attributes from `/api/taxons` are now returned within `taxons` subkey. Before:

```json
[{ name: 'Ruby' ... }]
```

Now:

```json
{ taxons: [{ name: 'Ruby' }]}
```

    * Ryan Bigg
