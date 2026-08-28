# The whole demo fulfillment setup in one place: a realistic parcel and
# Shopify-style delivery methods on the Domestic and International zones.
# The free international method showcases delivery-method rules — free
# above a spend threshold, hidden below it.
store = Spree::Store.default

# The zones are created from the store's country at first-run setup, so an
# install that has not been set up yet has none. Provision them here from
# whatever country the store already names rather than abort — sample data
# should be loadable on a bare seed.
if store.delivery_zones.where(name: %w[Domestic International]).count < 2
  Spree::Stores::ProvisionDefaults.call(
    store: store,
    country: store.default_country || Spree::Country.by_iso('US'),
    locale: store.default_locale
  )
  store.reload
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
  abort "Couldn't provision the Domestic/International delivery zones for this store."
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
