begin
north_america = Spree::Zone.find_by_name!("North America")
rescue ActiveRecord::RecordNotFound
  puts "Couldn't find 'North America' zone. Did you run `rake db:seed` first?"
  puts "That task will set up the countries, states and zones required for Spree."
  exit
end

europe_vat = Spree::Zone.find_by_name!("EU_VAT")
shipping_category = Spree::ShippingCategory.find_by_name!("Default")

shipping_methods = [
  {
    :name => "UPS Ground (USD)",
    :zones => [north_america],
    :calculator => Spree::Calculator::Shipping::FlatRate.create!,
    :shipping_categories => [shipping_category]
  },
  {
    :name => "UPS Two Day (USD)",
    :zones => [north_america],
    :calculator => Spree::Calculator::Shipping::FlatRate.create!,
    :shipping_categories => [shipping_category]
  },
  {
    :name => "UPS One Day (USD)",
    :zones => [north_america],
    :calculator => Spree::Calculator::Shipping::FlatRate.create!,
    :shipping_categories => [shipping_category]
  },
  {
    :name => "UPS Ground (EUR)",
    :zones => [europe_vat],
    :calculator => Spree::Calculator::Shipping::FlatRate.create!,
    :shipping_categories => [shipping_category]
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
  shipping_method.shipping_categories << Spree::ShippingCategory.first
  shipping_method.save!
end

