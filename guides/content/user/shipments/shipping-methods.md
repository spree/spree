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

To handle this use case in Spree you would define a "Default" shipping category for the jump rope and any other products that can use standard shipping methods and an "Over-sized" shipping category for extremely large items like the treadmill. You would then assign the "Over-sized" shipping category to your treadmill product and the "Default" shipping category to your jump rope product. 

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

# Flat Rate (per order)

The Flat Rate (per order) calculator allows you to charge the same shipping price per order regardless of the number of items in the order. You can define the flat rate charged per order at the Shipping Method level. For example, if you have two Shipping Methods defined for your store ("UPS 1-Day" and "UPS 2-Day") and have selected "Flat Rate (per order)" as the Calculator type for each, you could charge a $15 flat rate shipping cost for the UPS 1-Day orders and a $10 flat rate shipping cost for the UPS 2-Day orders. To modify these settings, go to the Admin Interface. Click on "Shipping Methods" and then click on the "Edit" icon next to the shipping method you would like to modify. 

![Flat Rate Shipping Per Order](/images/user/edit_flat_rate_calculator.jpg) 

Enter the updated "Amount" you would like to charge for orders that meet the Flat Rate (per order) shipping criteria for the Shipping Method you are editing. Click "Update" once complete. 

![Edit Flat Rate Per Order Amount](/images/user/flat_rate_amount.jpg)

# Flat Rate (per item/product) 

The Flat Rate (per item/product) calculator allows you to determine the shipping costs based on the number of items in the order. For example, if there are 4 items in an order and the flat rate per item amount is set to $10 then the total shipping costs for the order would be $40. You can modify the flat rate per item/product charge by following the same instructions used to modify the [Flat Rate (per order)](user/shipping-methods.html) shipping amount. 
$$$
Fix link
$$$

# Flat Percent

The Flat Percent calculator allows you to calculate shipping costs as a percent of the total amount charged for the order. The amount is calculated as follows:

```ruby
[item total] x [flat percentage]```

For example, if an order had an item total of $31 and the calculator was configured to have a flat percent amount of 10, the discount would be $3.10, because $31 x 10% = $3.10. 

To modify the flat percent amount, go to the Admin Interface. Click on "Shipping Methods" and then click on the "Edit" icon next to the shipping method you would like to modify. If "Flat Percent" is not already selected as the Calculator type, then select it from the "Calculator" drop down menu and click "Update". Once complete, a field will appear named "Flat Percent" where you can enter the value for the flat percentage you would like to charge for shipping costs per order. If "Flat Percent" is already selected as the Calculator type then you can jump to the step where you enter the flat percentage amount in the "Flat Percent" field. Click "Update" once complete. 

![Enter Flat Percent](/images/user/enter_flat_percent.jpg)

# Flexible Rate

The Flexible Rate calculator is typically used for promotional discounts when you want to give a specific discount for the first product, and then subsequent discounts for other products, up to a certain amount. For example, if you wanted to charge $10 for the first item, $5 for the next 3 items, and $0 for items beyond 

# Price Sack

Flexible rate is defined as a flat rate for the first product, plus a different flat rate for each additional product.

# Custom Calculators 

You can define your own calculator if you have more complex needs. In that case, check out the [Calculators Guide](../developer/calculators.html).

## Shipping Methods

Shipping methods are the services used to send the product. For example:

* UPS Ground
* UPS One Day
* FedEx 2Day
* FedEx Overnight
* DHL International

Each shipping method is only applicable to a specific Zone. For example, you wouldn’t be able to get a package delivered internationally using a domestic-only shipping method. You can’t ship from Dallas, USA to Rio de Janeiro, Brazil using UPS Ground (a US-only carrier).

