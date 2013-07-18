---
title: Shipping Methods
---

## Introduction

Spree uses a very flexible and effective system to calculate shipping, accommodating the full range of shipment pricing: from simple flat rate to complex product-type and weight-dependent calculations. This guide explains how Spree represents shipping options, how it calculates expected costs, and how you can configure the system with your own shipping methods.

To properly leverage Spree’s shipping system’s flexibility you must understand a few key concepts:

* Shipping Categories
* Zones
* Calculators (through Shipping Rates)
* Shipping Methods

## Shipping Categories

Shipping Categories are used to address special shipping needs for one or more products. The most common scenario where shipping categories are useful is when one or more products cannot be shipped in the same box. This is often due to a size or material constraint. For example, if a customer purchases a jump rope and a treadmill from an online exercise equipment store, the treadmill would be considered an over-sized item by most shipping carriers and would require special shipping arrangements. The jump rope could be sent via regular shipping methods. 

To handle this use case in Spree you could define a "Default" shipping category for the jump rope and any other products that can use standard shipping methods and an "Over-Sized" shipping category for extremelly large items like the treadmill. 

During checkout, the shipping categories assigned to the products in your order will determine which calculator is used to price the shipping costs for each Shipping Method. More on Calculators below. 

# Create Shipping Category

To create a new shipping category, go to the Admin Interface, click on the "Configuration" tab, click on the "Shipping Categories" link, and then click the "New Shipping Category button. Enter a name for your new shipping category and click "Update" once complete. 

$$$
Spree stores come with a "Default Shipping" shipping category defined by default. 
$$$

![New Shipping Category](/images/user/new_shipping_category.jpg)

# Add Shipping Category to a Product

Once you've created your shipping categories you can now assign the appropriate category to each of your products. To associate a Shipping Category with a product, go to the Admin Interface, click on the "Products" tab. Click on the product that you would like to edit from the list that appears. 

![Select Shipping Category](/images/user/select_shipping_category.jpg)

When you create a new product, you choose which shipping category you would like to associate with the product. 

## Shipping Methods

Shipping methods are the services used to send the product. For example:

* UPS Ground
* UPS One Day
* FedEx 2Day
* FedEx Overnight
* DHL International

Each shipping method is only applicable to a specific Zone. For example, you wouldn’t be able to get a package delivered internationally using a domestic-only shipping method. You can’t ship from Dallas, USA to Rio de Janeiro, Brazil using UPS Ground (a US-only carrier).

## Zones

Zones serve as a mechanism for grouping geographic areas together into a single entity. A zone is comprised of many different "zone members", which can either be a set of countries or a set of states.

The Shipping Address entered during checkout will define the zone the customer is in and limit the Shipping Methods available to him.



## Calculators

A Calculator is the component responsible for calculating the shipping price for each available Shipping Method.

Spree ships with 4 default Calculators:

* Flat rate (per order)
* Flat rate (per item/product)
* Flat percent
* Flexible rate
* Price sack

Flexible rate is defined as a flat rate for the first product, plus a different flat rate for each additional product.

You can define your own calculator if you have more complex needs. In that case, check out the [Calculators Guide](developer/calculators.html).

