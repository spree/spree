---
title: Manual Order Entry
---

## Introduction

An order can be created one of two ways:

1. An order is generated when a customer purchases an item from your store.
2. An order can be created manually from the Admin Interface for your store.

This guide covers how to create a manual order from the Admin Interface.

## Create Order

To create a new manual order, go into the Admin Interface, click the "Orders" tab, and click the "New Order" button.

![Create New Order](/images/user/create_new_order.jpg)

Type the name of the product you would like to add to the order in the search field. A list of matching product and variant combinations will return in the drop down menu. Select the product/variant option you want to add to the order as well as the quantity for that item. Then click the "Add" button to add that item to the order. Follow the same steps to add more products to the same order. Click the "Update" button at the bottom of the page once complete.

![Create New Order](/images/user/order_product_search.jpg)

## Customer Details

Enter the customer's billing address and shipping address for the order. You can click the "USE BILLING ADDRESS" checkbox to use the same address for both. If the order is for an existing customer, you can search for the customer in the "Customer Search" field.

$$$
Customer data isn't being returned for existing customers in the Sandbox
$$$

If the order is for a new customer, then enter that person's billing and shipping address in the fields provided. Click the "Continue" button once complete.

![Enter Customer Details](/images/user/order_customer_details.jpg)

## Shipment Details

Select the desired shipping method for the order. The shipping options that you have configured for your store will appear in the drop down menu based on the shipping address provided in the previous step and the shipping categories on the individual products.

Click the "Update" button once complete.

$$$
Is the Tracking field ever pre-populated with a tracking number?For example, if the user's store is integrate with USPS? No, because you'd have to post the package(s) and the service could return the tracking #s. But is this even the best implementation (having place for a single tracking #), since we could be sending this order out in split shipments? Should ping Brian about this when the Integrator storm has passed.
$$$

![Select Shipping Option](/images/user/select_shipping.jpg)

## Adjustments

The Adjustments page will appear, showing any additional charges that are applicable for the order. This includes things like shipping costs and taxes. You can edit the amount for any of these charges by clicking the "Edit" icon next to the charge. You can also remove any of the charges by clicking the "Delete" icon next to the charge. If you need to add additional charges, you can do so by clicking on the "New Adjustments" button and entering the necessary information. Click the "Continue" button once you've confirmed the adjustments are correct.

![Review Adjustments](/images/user/order_adjustments.jpg)

$$$
Finish documenting the rest of the steps once the bug is fixed. Currently, I can only get through the Adjustments step
$$$

## Payments

## Shipments