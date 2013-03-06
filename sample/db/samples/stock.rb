Spree::Sample.load_sample("variants")

location = Spree::StockLocation.first_or_create! do |stock_location|
  stock_location.name = 'default'
  stock_location.active = true
  stock_location.country =  Spree::Countries.where(iso: 'US').first
end

Spree::Variant.all.each do |variant|
  location.stock_items.create(variant: variant, count_on_hand: 10)
end

