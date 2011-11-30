shipping_method = Spree::ShippingMethod.find_by_name("UPS Ground")
shipping_method.calculator.preferred_amount = 5

shipping_method = Spree::ShippingMethod.find_by_name("UPS One Day")
shipping_method.calculator.preferred_amount = 15

shipping_method = Spree::ShippingMethod.find_by_name("UPS Two Day")
shipping_method.calculator.preferred_amount = 10

# flat_rate_five_dollars:
#   name: amount
#   owner: flat_rate_coupon_calculator
#   owner_type: Spree::Calculator
#   value: 5
