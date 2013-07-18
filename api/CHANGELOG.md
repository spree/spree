## Spree 2.0.4 (unreleased)

* PUT requests to Checkouts API endpoints now require authorization to alter an order.

    *Ryan Bigg*

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