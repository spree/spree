Spree::Sample.load_sample("variants")

location = Spree::StockLocation.first_or_create! name: 'default'
location.active = true
location.country =  Spree::Country.where(iso: 'US').first
location.save!

Spree::Variant.all.each do |variant|
  si = location.stock_items.create(variant: variant, count_on_hand: 10)
  Spree::StockMovement.create!(:action => 'received', :quantity => 10, :stock_item => si)
end

