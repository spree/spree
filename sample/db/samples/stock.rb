Spree::Sample.load_sample('variants')

country =  Spree::Country.find_by(iso: 'US')
location = Spree::StockLocation.find_or_create_by!(name: Spree.t(:default_stock_location_name), propagate_all_variants: false)
location.update(
  address1: 'Example Street',
  city: 'City',
  zipcode: '12345',
  country: country,
  state: country.states.first,
  active: true
)

Spree::StockLocations::StockItems::Create.call(stock_location: location)

product_1 = Spree::Product.find_by!(name: 'Denim Shirt')
product_2 = Spree::Product.find_by!(name: 'Checked Shirt')

location.stock_item_or_create(product_1.master).update(count_on_hand: 1)
location.stock_item_or_create(product_2.master).update(count_on_hand: 1)

Spree::Variant.eligible.includes(:stock_items).each do |variant|
  variant.stock_items.each do |stock_item|
    Spree::StockMovement.create(quantity: rand(20..50), stock_item: stock_item)
  end
end
