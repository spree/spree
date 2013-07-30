---
title: Calculators
---

## Calculators

A Calculator is the component responsible for calculating the shipping price for each available Shipping Method.

Spree ships with 5 default Calculators:

* Flat rate (per order)
* Flat rate (per item/product)
* Flat percent
* Flexible rate
* Price sack

### Flat Rate (per order)

The Flat Rate (per order) calculator allows you to charge the same shipping price per order regardless of the number of items in the order. You can define the flat rate charged per order at the Shipping Method level. For example, if you have two Shipping Methods defined for your store ("UPS 1-Day" and "UPS 2-Day") and have selected "Flat Rate (per order)" as the Calculator type for each, you could charge a $15 flat rate shipping cost for the UPS 1-Day orders and a $10 flat rate shipping cost for the UPS 2-Day orders. To modify these settings, go to the Admin Interface. Click on "Shipping Methods" and then click on the "Edit" icon next to the shipping method you would like to modify.

![Flat Rate Shipping Per Order](/images/user/edit_flat_rate_calculator.jpg)

Enter the updated "Amount" you would like to charge for orders that meet the Flat Rate (per order) shipping criteria for the Shipping Method you are editing. Click "Update" once complete.

![Edit Flat Rate Per Order Amount](/images/user/flat_rate_amount.jpg)

### Flat Rate (per item/product)

The Flat Rate (per item/product) calculator allows you to determine the shipping costs based on the number of items in the order. For example, if there are 4 items in an order and the flat rate per item amount is set to $10 then the total shipping costs for the order would be $40. You can modify the flat rate per item/product charge by following the same instructions used to modify the [Flat Rate (per order)](user/shipping-methods.html) shipping amount.
$$$
Fix link
$$$

### Flat Percent

The Flat Percent calculator allows you to calculate shipping costs as a percent of the total amount charged for the order. The amount is calculated as follows:

```ruby
[item total] x [flat percentage]```

For example, if an order had an item total of $31 and the calculator was configured to have a flat percent amount of 10, the discount would be $3.10, because $31 x 10% = $3.10.

To modify the flat percent amount, go to the Admin Interface. Click on "Shipping Methods" and then click on the "Edit" icon next to the shipping method you would like to modify. If "Flat Percent" is not already selected as the Calculator type, then select it from the "Calculator" drop down menu and click "Update". Once complete, a field will appear named "Flat Percent" where you can enter the value for the flat percentage you would like to charge for shipping costs per order. If "Flat Percent" is already selected as the Calculator type then you can jump to the step where you enter the flat percentage amount in the "Flat Percent" field. Click "Update" once complete.

![Enter Flat Percent](/images/user/enter_flat_percent.jpg)

### Flexible Rate

The Flexible Rate calculator is typically used for promotional discounts when you want to give a specific discount for the first product, and then subsequent discounts for other products, up to a certain amount. For example, if you wanted to charge $10 for the first item, $5 for the next 3 items, and $0 for items beyond

### Price Sack

Flexible rate is defined as a flat rate for the first product, plus a different flat rate for each additional product.

### Custom Calculators

You can define your own calculator if you have more complex needs. In that case, check out the [Calculators Guide](../developer/calculators.html).