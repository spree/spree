---
  title: "Core | Models | Order"
---

## Order

The Order model is one of the central models in Spree, providing a central place to
collect information about the order, including line items, <%= link_to "adjustments", :adjustments %>,
 <%= link_to "payments", :payments %>, addresses, return authorizations, 
<%= link_to "inventory units", "#" %>, and shipments.

Every order that is created within Spree is given its own unique identifier,
beginning with the letter R and ending in a 9-digit number. This unique number
is shown to the users, and can be used to find the Order by calling
`Spree::Order.find_by_number(number)`.

Orders have the following attributes:

* `number`: The unique identifier for this order.
* `item_total`: The sum of all the line items for this order.
* `adjustment_total`: The sum of all adjustments on this order.
* `total`: The sum of `item_total` minus the `adjustment_total`.
* `state`: The current state of the order.
* `email`: The email address for the user who placed this order. Stored in case
this order is for a guest user.
* `user_id`: The ID for the corresponding user record for this order. Stored
only if the order is placed by a signed-in user.
* `completed_at`: The timestamp of when the order was completed:
* `bill_address_id`: The ID for the related `Address` object with billing
address information.
* `ship_address_id`: The ID for the related `Address` object with shipping
address information.
* `shipment_state`: The current shipment state of the order. For possible
states, please see the <%= link_to "Shipping guide", "#" %>
* `payment_state`: The current payment state of the order. For possible states,
please see the <%= link_to "Payments guide", "#" %>
* `special_instructions`: Any special instructions for the store to do with this
order. Will only appear if `Spree::Config[:shipping_instructions]` is set to
`true`.
* `currency`: The currency for this order. Determined by the
`Spree::Config[:currency]` value that was set at the time of order.
* `last_ip_address`: The last IP address used to update this order in the
frontend.

## The Order State Machine

Orders flow through a state machine, beginning at a "cart" start and ending up
at a "complete" state. The intermediary states can be configured using the
[Checkout Flow API](/developer/core/customization/checkout_flow).

The default states are as follows:

* Cart
* Address
* Delivery
* Payment
* Confirm
* Complete

The "Payment" state will only be triggered if `payment_required?`
returns `true`.

The "Confirm" state will only be triggered if `confirmation_required?` returns `true`.

The "Complete" state can only be reached in one of two states:

1. No payment is required on the order.
2. Payment is required on the order, and at least the order total has been
received as payment.

Assuming that an order meets the criteria for the next state, you will be able
to transition it to the next state by calling `next` on that object. If this
returns `false`, then the order does *not* meet the criteria. To work out why it
cannot transition, check the result of an `errors` method call.

## Line Items

Line items are used to keep track of items within the context of an order.
 These records provide a link between orders,
and <%= link_to "Variants", :variants %>.

When a variant is added to an order, the price of that item is tracked along 
with the line item to preserve that data. If the variant's price were to change,
then the line item would still have a record of the price at the time of ordering.

* Inventory tracking notes to go here after Chris+Brian have done their thing.


