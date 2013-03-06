Spree::Sample.load_sample("variants")

location = Spree::StockLocation.first_or_create(name: 'default', active: true, country_id: Spree::Countries.where(iso: 'US').first.id)

Spree::Variant.all.each do |variant|
  location.stock_items.create(variant: variant, count_on_hand: 10)
end

