---
title: Shipping Methods
---

## Introduction

Spree uses a very flexible and effective system to calculate shipping. This guide explains how Spree represents shipping options, how it calculates expected costs, and how you can configure the system with your own shipping methods.

To properly leverage Spree’s shipping system’s flexibility you must understand a few key concepts:

* Shipping Categories
* Zones
* Calculators (through Shipping Rates)
* Shipping Methods

## Shipping Categories

Shipping Categories are used to address special shipping needs for one or more of your products. The most common use for shipping categories is when one or more products cannot be shipped in the same box. This is often due to a size or material constraint. For example, if a customer purchases a jump rope and a treadmill from an online exercise equipment store, the treadmill would be considered an over-sized item by most shipping carriers and would require special shipping arrangements. The jump rope could be sent via standard shipping. 

To handle this use case in Spree you would define a "Default" shipping category for the jump rope and any other products that can use standard shipping methods and an "Over-sized" shipping category for extremelly large items like the treadmill. You would then assign the "Over-sized" shipping vategory to your treadmill product and the "Default" shipping category to your jump rope product. 

During checkout, the shipping categories assigned to each of the products in your customer's order will determine which calculator is used to price the shipping costs for each Shipping Method. More on Calculators below. 

# Create a Shipping Category

To create a new shipping category, go to the Admin Interface, click on the "Configuration" tab, click on the "Shipping Categories" link, and then click the "New Shipping Category" button. Enter a name for your new shipping category and click "Create" once complete. 

![New Shipping Category](/images/user/new_shipping_category.jpg)

# Add a Shipping Category to a Product

Once you've created your Shipping Categories you can assign the appropriate category to each of your products. To associate a Shipping Category with a product, go to the Admin Interface, and click on the "Products" tab. Then click on the product that you would like to edit from the list that appears. 

Once you are in edit mode for the selected product, go to the "Shipping Categories" drop down menu and type the name of the shipping category that you would like to associate with the product. Once the right name appears, select it and click "Update".

![Select Shipping Category](/images/user/select_shipping_category.jpg) 

## Zones

Zones serve as a mechanism to define shipping rules for a particular geographic area. A zone is comprised of a set of countries or a set of states. Zones are utilized within Spree when defining the rules for a Shipping Method. Each Shipping Method is only applicable for a particular Zone. For example, if one of the shipping methods for your store is UPS ground (a U.S. only shipping carrier) then the Zone for that shipping method should be defined as the United States only. When the customer enters their shipping address during checkout Spree uses that information to determine which zone the customer is in and only presents the Shipping Methods to the customer that are defined for their Zone. 

# Create a Zone 

To create a new Zone, go to the Admin Interface, click on the "Configuration" tab, click on the "Zones" link, and then click on the "New Zone" button. Enter a name and description for your new Zone. Decide if you want it to be the default Zone selected when you create a new Shipping Category. Choose if you want the Zone to be country based or state based. Click "Create" once complete.

![New Zone](/images/user/new_zone.jpg) 

Now you need to go back and add the countries or states associated with that Zone. To do this, go back to the Zones list. Click on the "Edit" icon next to the Zone you just created. Click on the "Add Country" or "Add State" button to associate a country or state with the Zone. Choose a country or state from the drop down menu and click the "Add Country" or "Add State" button. Follow the same steps to add additional countries or states for the Zone. Click "Update" once complete. 

![Add Country or State](/images/user/add_country.jpg) 

## Calculators

A Calculator is the component responsible for calculating the shipping price for each available Shipping Method.

Spree ships with 5 default Calculators:

* Flat rate (per order)
* Flat rate (per item/product)
* Flat percent
* Flexible rate
* Price sack

# Flate Rate (per order)

The Flate Rate calculator allows you to charge the same shipping price per order regardless of the number of items in the order. You can define the flat rate charged per order at the Shipping Method level. For example, if you have two Shipping Methods defined for your store ("UPS 1-Day" and "UPS 2-Day") and have selected "Flat Rate (per order)" as the Calculator type for each, you could charge a $15 flat rate shipping cost for the UPS 1-Day orders and a $10 flat rate shipping cost for the UPS 2-Day orders. To modify these settings, do to the Admin Interface. Click on "Shipping Methods" and then click on the "Edit" icon next to the shipping method you would like to modify. 

# Flat Rate (per item/product)

# Flat Percent

# Flexible Rate

# Price Sack

Flexible rate is defined as a flat rate for the first product, plus a different flat rate for each additional product.

You can define your own calculator if you have more complex needs. In that case, check out the [Calculators Guide](developer/calculators.html).

## Shipping Methods

Shipping methods are the services used to send the product. For example:

* UPS Ground
* UPS One Day
* FedEx 2Day
* FedEx Overnight
* DHL International

Each shipping method is only applicable to a specific Zone. For example, you wouldn’t be able to get a package delivered internationally using a domestic-only shipping method. You can’t ship from Dallas, USA to Rio de Janeiro, Brazil using UPS Ground (a US-only carrier).

