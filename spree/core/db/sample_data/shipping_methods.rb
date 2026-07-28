# Delivery zones are built from the seeded (tax) zones' geography — the Zone
# model itself no longer links to delivery methods.
def delivery_zone_from(zone)
  return nil if zone.nil?

  delivery_zone = Spree::DeliveryZone.find_or_create_by!(name: zone.name) do |dz|
    dz.description = zone.description
  end
  zone.countries.each { |country| delivery_zone.members.find_or_create_by!(member_type: 'country', country: country) }
  zone.states.each { |state| delivery_zone.members.find_or_create_by!(member_type: 'state', state: state) }
  delivery_zone
end

begin
  north_america = delivery_zone_from(Spree::Zone.find_by!(name: 'North America'))
rescue ActiveRecord::RecordNotFound
  puts "Couldn't find 'North America' zone. Did you run `rake db:seed` first?"
  exit
end

europe_vat = delivery_zone_from(Spree::Zone.find_by!(name: 'EU_VAT'))
central_america_and_caribbean = delivery_zone_from(Spree::Zone.find_by(name: 'Central America and Caribbean'))
south_america = delivery_zone_from(Spree::Zone.find_by(name: 'South America'))
middle_east = delivery_zone_from(Spree::Zone.find_by(name: 'Middle East'))
africa = delivery_zone_from(Spree::Zone.find_by(name: 'Africa'))
asia = delivery_zone_from(Spree::Zone.find_by(name: 'Asia'))
australia_and_oceania = delivery_zone_from(Spree::Zone.find_by(name: 'Australia and Oceania'))

delivery_methods = [
  { name: 'UPS Ground (USD)', delivery_zones: [north_america], display_on: 'both' },
  { name: 'UPS Two Day (USD)', delivery_zones: [north_america], display_on: 'both' },
  { name: 'UPS One Day (USD)', delivery_zones: [north_america], display_on: 'both' },
  { name: 'UPS Ground (EU)', delivery_zones: [europe_vat], display_on: 'both' },
  { name: 'UPS Ground (EUR)', delivery_zones: [europe_vat], display_on: 'both' },
  { name: 'DHL Standard (Central America and Caribbean)', delivery_zones: [central_america_and_caribbean].compact, display_on: 'both' },
  { name: 'DHL Standard (South America)', delivery_zones: [south_america].compact, display_on: 'both' },
  { name: 'DHL Standard (Middle East)', delivery_zones: [middle_east].compact, display_on: 'both' },
  { name: 'DHL Standard (Africa)', delivery_zones: [africa].compact, display_on: 'both' },
  { name: 'DHL Standard (Asia)', delivery_zones: [asia].compact, display_on: 'both' },
  { name: 'DHL Standard (Australia and Oceania)', delivery_zones: [australia_and_oceania].compact, display_on: 'both' }
]

delivery_methods.each do |attributes|
  next if attributes[:delivery_zones].empty?

  Spree::DeliveryMethod.where(name: attributes[:name]).first_or_create! do |delivery_method|
    delivery_method.calculator = Spree::Calculator::Shipping::FlatRate.create!
    delivery_method.delivery_zones = attributes[:delivery_zones]
    delivery_method.display_on = attributes[:display_on]
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
}.each do |delivery_method_name, (price, currency)|
  delivery_method = Spree::DeliveryMethod.find_by(name: delivery_method_name)
  next unless delivery_method

  delivery_method.calculator.preferences = { amount: price, currency: currency }
  delivery_method.calculator.save!
  delivery_method.save!
end
