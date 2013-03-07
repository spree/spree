Spree::Sample.load_sample("variants")

location = Spree::StockLocation.first_or_create!
location.name = 'default'
location.active = true
location.country =  Spree::Country.where(iso: 'US').first
location.save!

Spree::Variant.all.each do |variant|
  location.stock_items.create(variant: variant, count_on_hand: 10)
end

