---
title: Order States
---

## Introduction

A new order is initiated when a customer places a product in their shopping cart. The order then passes through several states before it is considered **Complete**. The order states are listed below. An order cannot continue to the next state until the previous state has been succesfully completed. For example, an order cannot proceed to the **Delivery** state until the customer has provided their billing and shipping address for the order.

## Order States

* **Cart** - One or more products have been added to the Shopping Cart
* **Address** - The store is ready to receive the billing and shipping address information for the order. 
* **Delivery** - The store is ready to receive the shipping method for the order. 
* **Payment** - The store is ready to receive the payment information for the order.
* **Confirm** - The order is ready for a final review by the customer before being processed. 
* **Complete** - The order has successfully completed all of the previous states and is now being processed. 

***
The states described above are the default settings for Spree stores. You can customize the order states to suit your needs utilizing our API. This includes adding, removing or changing the order of certain states. Customization details are provided in the [Checkout Flow API Guide](developer/checkout.html#checkout-customization). 
***
