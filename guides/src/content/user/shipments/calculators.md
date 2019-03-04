---
title: Calculators
---

## Calculators

A Calculator is the component of the Spree shipping system responsible for calculating the shipping price for each available [Shipping Method](/user/shipments/shipping_methods.html).

Spree ships with 5 default calculators:

* [Flat rate (per order)](#flat-rate-per-order)
* [Flat rate (per item)](#flat-rate-per-item)
* [Flat percent](#flat-percent)
* [Flexible rate](#flexible-rate)
* [Price sack](#price-sack)

### Flat Rate (per order)

The Flat Rate (per order) calculator allows you to charge the same shipping price per order regardless of the number of items in the order. You define the flat rate charged per order at the shipping method level.

For example, if you have two shipping methods defined for your store ("UPS 1-Day" and "UPS 2-Day"), and have selected "Flat rate" as the calculator type for each, you could charge a $15 flat rate shipping cost for the UPS 1-Day orders and a $10 flat rate shipping cost for the UPS 2-Day orders.

### Flat Rate (per item)

The Flat Rate (per item/product) calculator allows you to determine the shipping costs based on the number of items in the order.

For example, if there are 4 items in an order and the flat rate per item amount is set to $10 then the total shipping costs for the order would be $40.

### Flat Percent

The Flat Percent calculator allows you to calculate shipping costs as a percent of the total amount charged for the order. The amount is calculated as follows:

`ruby
[item total] x [flat percentage]`

For example, if an order had an item total of $31 and the calculator was configured to have a flat percent amount of 10, the shipping cost would be $3.10, because $31 x 10% = $3.10.

### Flexible Rate

The Flexible Rate calculator is typically used for promotional discounts when you want to give a specific discount for the first product, and then subsequent discounts for other products, up to a certain amount.

The Flexible Rate calculator takes four inputs:

* First Item Cost: the amount of shipping charged for the first item in the order.
* Additional Item Cost: the amount of shipping charged for items beyond the first item.
* Max Items: the maximum number of items on which shipping will be calculated.
* Currency: defaults to the currency you have configured for your store.

For example, if you set First Item Cost to $10, Additional Item Cost to $5, and Max Items to 4, you could be charging $10 for the first item, $5 for the next 3 items, and $0 for items beyond the first 4. Thus, an order with 1 item would have a shipping cost of $10. An order with two items would cost $15 to ship, and an order of 7 items would cost $25 to ship.

### Price Sack

The Price Sack calculator is a way to offer discount shipping to orders over a certain dollar amount. The Price Sack calculator takes four inputs:

* Minimal Amount
* Normal Amount
* Discount Amount
* Currency (defaults to the currency you have configured for your store)

Any order whose subtotal is under is less than what you set for Minimal Amount would be charged a shipping cost of Normal Amount. Orders whose subtotals are equal to or greater than the Minimal Amount would be charged the Discount Amount.

For example, suppose you create a shipping calculator with these settings:

* Minimal Amount - $50
* Normal Amount - $15
* Discount Amount - $5

A customer whose order subtotal equals $35 would be offered a shipping cost of $15 using this shipping method. A different customer whose order subtotal equals $55 would be offered a shipping cost of only $5.

### Custom Calculators

You can define your own calculator if you have more complex needs. In that case, check out the [Calculators Guide](../developer/calculators.html).

## Next Step

If you have followed this guide series [from the beginning](shipments), your store is now stocked with [shipping categories](shipping_categories), [geographical shipping zones](zones), and calculators. The final step is to pull it all together into [shipping methods](shipping_methods), from which your customers can choose at checkout.
