# Shopify-style delivery setup: the seeded Domestic and International zones
# (Spree::Seeds::DeliveryZones) with a small set of realistic methods. The
# free international method showcases delivery-method rules — free above a
# spend threshold, hidden below it.
store = Spree::Store.default

domestic = store.delivery_zones.find_by(name: 'Domestic')
international = store.delivery_zones.find_by(name: 'International')

if domestic.nil? || international.nil?
  puts "Couldn't find the Domestic/International delivery zones. Did you run `rake db:seed` first?"
  exit
end

currency = store.default_currency

delivery_methods = [
  { name: 'Standard', zone: domestic, amount: 5 },
  { name: 'Express', zone: domestic, amount: 15 },
  { name: 'International Shipping', zone: international, amount: 20 },
  { name: 'Free International Shipping', zone: international, amount: 0, minimum_item_total: 100 }
]

delivery_methods.each do |attributes|
  delivery_method = Spree::DeliveryMethod.where(name: attributes[:name], store: store).first_or_create! do |record|
    record.calculator = Spree::Calculator::Shipping::FlatRate.create!(
      preferences: { amount: attributes[:amount], currency: currency }
    )
    record.delivery_profile = attributes[:zone].delivery_profile
    record.delivery_zone = attributes[:zone]
    record.storefront_visible = true
  end

  next if attributes[:minimum_item_total].blank?

  Spree::DeliveryMethodRules::ItemTotalRule.where(delivery_method: delivery_method).first_or_create! do |rule|
    rule.active = true
    rule.preferred_minimum_amount = attributes[:minimum_item_total]
  end
end
