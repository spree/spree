---
title: Order States
---

## Introduction

A new order is initiated when a customer places a product in their shopping cart. The order then passes through several states before it is considered `complete`. The order states are listed below. An order cannot continue to the next state until the previous state has been successfully satisfied. For example, an order cannot proceed to the `delivery` state until the customer has provided their billing and shipping address for the order during the `address` state.

## Order States

The states that an order passes through are as follows:

* `cart` - One or more products have been added to the shopping cart.
* `address` - The store is ready to receive the billing and shipping address information for the order.
* `delivery` - The store is ready to receive the shipping method for the order.
* `payment` - The store is ready to receive the payment information for the order.
* `confirm` - The order is ready for a final review by the customer before being processed.
* `complete` - The order has successfully completed all of the previous states and is now being processed.

***
The states described above are the default settings for a Spree store. You can customize the order states to suit your needs utilizing our API. This includes adding, removing, or changing the order of certain states. Customization details are provided in the [Checkout Flow API Guide](/developer/checkout.html#checkout-customization).
***
