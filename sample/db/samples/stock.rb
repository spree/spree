Spree::Sample.load_sample("variants")

location = Spree::StockLocation.first_or_create! name: 'default'
location.active = true
location.country =  Spree::Country.where(iso: 'US').first
location.save!

Spree::Variant.all.each do |variant|
  variant.stock_items.each do |stock_item|
    Spree::StockMovement.create(:quantity => 10, :stock_item => stock_item)
  end
end
