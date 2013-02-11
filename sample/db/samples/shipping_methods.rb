north_america = Spree::Zone.find_by_name!("North America")
europe_vat = Spree::Zone.find_by_name!("EU_VAT")

shipping_methods = [
  {
    :name => "UPS Ground (USD)",
    :zone => north_america,
    :calculator => Spree::Calculator::FlatRate.create!
  },
  {
    :name => "UPS Two Day (USD)",
    :zone => north_america,
    :calculator => Spree::Calculator::FlatRate.create!
  },
  {
    :name => "UPS One Day (USD)",
    :zone => north_america,
    :calculator => Spree::Calculator::FlatRate.create!
  },
  {
    :name => "UPS Ground (EUR)",
    :zone => europe_vat,
    :calculator => Spree::Calculator::FlatRate.create!
  }
]

shipping_methods.each do |shipping_method_attrs|
  Spree::ShippingMethod.create!(shipping_method_attrs, :without_protection => true)
end

{
  "UPS Ground (USD)" => [5, "USD"],
  "UPS Ground (EUR)" => [5, "EUR"],
  "UPS One Day (USD)" => [15, "USD"],
  "UPS Two Day (USD)" => [10, "USD"]
}.each do |shipping_method_name, (price, currency)|
  shipping_method = Spree::ShippingMethod.find_by_name!(shipping_method_name)
  shipping_method.calculator.preferred_amount = price
  shipping_method.calculator.preferred_currency = currency
  shipping_method.save!
end

