Spree::Sample.load_sample('variants')

country =  Spree::Country.find_by(iso: 'US')
location = Spree::StockLocation.find_or_create_by!(name: 'default')
location.update_attributes!(
  address1: 'Example Street',
  city: 'City',
  zipcode: '12345',
  country: country,
  state: country.states.first,
  active: true
)

product_1 = Spree::Product.find_by!(name: 'Denim Shirt')
product_2 = Spree::Product.find_by!(name: 'Checked Shirt')

product_1.master.stock_items.find_by!(stock_location: location).update!(count_on_hand: 1)
product_2.master.stock_items.find_by!(stock_location: location).update!(count_on_hand: 1)

Spree::Variant.all.each do |variant|
  next if variant.is_master? && variant.product.has_variants?

  variant.stock_items.each do |stock_item|
    Spree::StockMovement.create(quantity: rand(20..50), stock_item: stock_item)
  end
end
