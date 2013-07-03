## Spree 2.0.4 (unreleased)

* PUT requests to Checkouts API endpoints now require authorization to alter an order.

    *Ryan Bigg*

* Checkouts API's update action will now correctly process line item attributes (either `line_items` or `line_item_attributes`)

    * Ryan Bigg*

* Checkouts API now correctly processes incoming payment data during the payment step.

    *Ryan Bigg*

* Fix issue where `set_current_order` before filter would be called when CheckoutsController actions were run, causing the order object to be deleted. #3306

    *Ryan Bigg*