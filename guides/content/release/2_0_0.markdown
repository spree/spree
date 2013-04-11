Spree 2.0.0 Release Notes
-------------------------

endprologue.

### Minor changes

#### API CheckoutsController

The Spree API now has support for “checking out” an order. This API
functionality allows an existing order to be updated and advanced until
it is in the complete state.

For instance, if you have an order in the “confirm” state that you would
like to advance to the “complete” state, make the following request:

<shell>\
PUT /api/checkouts/ORDER\_NUMBER\
</shell>

For more information on using the new CheckoutsController, please see
the [Checkouts API
Documentation](http://api.spreecommerce.com/v1/order/checkouts/).
