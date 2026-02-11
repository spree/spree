country = Spree::Country.find_by(iso: 'US')
location = Spree::StockLocation.find_or_create_by!(name: Spree.t(:default_stock_location_name), propagate_all_variants: false)
location.update(
  address1: 'Example Street',
  city: 'City',
  zipcode: '12345',
  country: country,
  state: country&.states&.first,
  active: true
)

Spree::StockLocations::StockItems::Create.call(stock_location: location)
Spree::StockItem.update_all(backorderable: true, count_on_hand: 100)
