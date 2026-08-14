# The whole demo fulfillment setup in one place: a rate-ready origin, a
# realistic parcel, and Shopify-style delivery methods on the seeded Domestic
# and International zones (Spree::Seeds::DeliveryZones). The free
# international method showcases delivery-method rules — free above a spend
# threshold, hidden below it.
store = Spree::Store.default

# Carrier rate providers (EasyPost) cannot quote without a complete origin
# address — a country-only stock location makes every carrier method silently
# disappear from checkout. Demo data only: the production seed deliberately
# leaves the address blank rather than invent an origin real rates would be
# quoted from.
stock_location = store.stock_locations.find_by(default: true) || store.stock_locations.first

# Any missing field leaves the origin unquotable, so completeness — not just a
# blank street — decides whether the demo address applies.
if stock_location&.country&.iso == 'US' &&
   [stock_location.address1, stock_location.city, stock_location.state_id, stock_location.zipcode].any?(&:blank?)
  stock_location.update!(
    address1: '417 Montgomery St',
    city: 'San Francisco',
    state: stock_location.country.states.find_by!(abbr: 'CA'),
    zipcode: '94104',
    phone: '415-555-0100'
  )
end

# A realistic shipping box (imperial units — the demo store is US): its weight
# rides on every parcel and its dimensions feed dimensional-weight pricing,
# without which carrier quotes under-price bulky-but-light items. Applied only
# when nothing is configured, so a half-filled box is never completed with
# values the merchant did not choose.
package_preferences = %i[
  preferred_default_package_weight
  preferred_default_package_length
  preferred_default_package_width
  preferred_default_package_height
]

if package_preferences.all? { |preference| store.public_send(preference).to_f.zero? }
  store.preferred_default_package_weight = 0.5
  store.preferred_default_package_length = 12
  store.preferred_default_package_width = 9
  store.preferred_default_package_height = 4
  store.save!
end

domestic = store.delivery_zones.find_by(name: 'Domestic')
international = store.delivery_zones.find_by(name: 'International')

if domestic.nil? || international.nil?
  # abort, not exit: exit reports success and would silently skip the payment
  # methods and promotions the loader still has to seed.
  abort "Couldn't find the Domestic/International delivery zones. Did you run `rake db:seed` first?"
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
