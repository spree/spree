begin
  north_america = Spree::Zone.find_by!(name: 'North America')
rescue ActiveRecord::RecordNotFound
  puts "Couldn't find 'North America' zone. Did you run `rake db:seed` first?"
  exit
end

europe_vat = Spree::Zone.find_by!(name: 'EU_VAT')
central_america_and_caribbean = Spree::Zone.find_by(name: 'Central America and Caribbean')
south_america = Spree::Zone.find_by(name: 'South America')
middle_east = Spree::Zone.find_by(name: 'Middle East')
africa = Spree::Zone.find_by(name: 'Africa')
asia = Spree::Zone.find_by(name: 'Asia')
australia_and_oceania = Spree::Zone.find_by(name: 'Australia and Oceania')
shipping_category = Spree::ShippingCategory.find_or_create_by!(name: 'Default')

shipping_methods = [
  { name: 'UPS Ground (USD)', zones: [north_america], display_on: 'both', shipping_categories: [shipping_category] },
  { name: 'UPS Two Day (USD)', zones: [north_america], display_on: 'both', shipping_categories: [shipping_category] },
  { name: 'UPS One Day (USD)', zones: [north_america], display_on: 'both', shipping_categories: [shipping_category] },
  { name: 'UPS Ground (EU)', zones: [europe_vat], display_on: 'both', shipping_categories: [shipping_category] },
  { name: 'UPS Ground (EUR)', zones: [europe_vat], display_on: 'both', shipping_categories: [shipping_category] },
  { name: 'DHL Standard (Central America and Caribbean)', zones: [central_america_and_caribbean].compact, display_on: 'both', shipping_categories: [shipping_category] },
  { name: 'DHL Standard (South America)', zones: [south_america].compact, display_on: 'both', shipping_categories: [shipping_category] },
  { name: 'DHL Standard (Middle East)', zones: [middle_east].compact, display_on: 'both', shipping_categories: [shipping_category] },
  { name: 'DHL Standard (Africa)', zones: [africa].compact, display_on: 'both', shipping_categories: [shipping_category] },
  { name: 'DHL Standard (Asia)', zones: [asia].compact, display_on: 'both', shipping_categories: [shipping_category] },
  { name: 'DHL Standard (Australia and Oceania)', zones: [australia_and_oceania].compact, display_on: 'both', shipping_categories: [shipping_category] }
]

shipping_methods.each do |attributes|
  next if attributes[:zones].empty?

  Spree::ShippingMethod.where(name: attributes[:name]).first_or_create! do |shipping_method|
    shipping_method.calculator = Spree::Calculator::Shipping::FlatRate.create!
    shipping_method.zones = attributes[:zones]
    shipping_method.display_on = attributes[:display_on]
    shipping_method.shipping_categories = attributes[:shipping_categories]
  end
end

{
  'UPS Ground (USD)' => [5, 'USD'],
  'UPS Ground (EU)' => [5, 'USD'],
  'UPS One Day (USD)' => [15, 'USD'],
  'UPS Two Day (USD)' => [10, 'USD'],
  'UPS Ground (EUR)' => [8, 'EUR'],
  'DHL Standard (Central America and Caribbean)' => [15, 'USD'],
  'DHL Standard (South America)' => [20, 'USD'],
  'DHL Standard (Middle East)' => [20, 'USD'],
  'DHL Standard (Africa)' => [25, 'USD'],
  'DHL Standard (Asia)' => [20, 'USD'],
  'DHL Standard (Australia and Oceania)' => [25, 'USD']
}.each do |shipping_method_name, (price, currency)|
  shipping_method = Spree::ShippingMethod.find_by(name: shipping_method_name)
  next unless shipping_method

  shipping_method.calculator.preferences = { amount: price, currency: currency }
  shipping_method.calculator.save!
  shipping_method.save!
end
