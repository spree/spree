shipping_method = Spree::ShippingMethod.find_by_name("UPS Ground (USD)")
shipping_method.calculator.preferred_amount = 5
shipping_method.calculator.preferred_currency = 'USD'

shipping_method = Spree::ShippingMethod.find_by_name("UPS Ground (EUR)")
shipping_method.calculator.preferred_amount = 5
shipping_method.calculator.preferred_currency = 'EUR'

shipping_method = Spree::ShippingMethod.find_by_name("UPS One Day (USD)")
shipping_method.calculator.preferred_amount = 15
shipping_method.calculator.preferred_currency = 'USD'

shipping_method = Spree::ShippingMethod.find_by_name("UPS Two Day (USD)")
shipping_method.calculator.preferred_amount = 10
shipping_method.calculator.preferred_currency = 'USD'

# flat_rate_five_dollars:
#   name: amount
#   owner: flat_rate_coupon_calculator
#   owner_type: Spree::Calculator
#   value: 5
