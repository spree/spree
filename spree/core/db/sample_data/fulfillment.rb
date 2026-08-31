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
# without which carrier quotes under-price bulky-but-light items. Created only
# when the store has no default box, so a merchant's own is never replaced.
if store.default_package_type.nil?
  store.package_types.create!(
    name: 'Standard box',
    kind: 'box',
    default: true,
    weight: 0.5,
    length: 12,
    width: 9,
    height: 4,
    dimensions_unit: 'in',
    weight_unit: 'lb'
  )
end

# Wholesale packaging: the carton products are packed into, and the pallet
# those cartons stack onto. A merchant configuring freight starts from rows
# like these.
[
  { name: 'Master carton', kind: 'carton', length: 40, width: 30, height: 25, weight: 0.4, max_weight: 20 },
  { name: 'Euro pallet', kind: 'pallet', length: 120, width: 80, height: 15, weight: 25, max_weight: 1_500 }
].each do |attributes|
  store.package_types.where(name: attributes[:name]).first_or_create! do |package_type|
    package_type.assign_attributes(attributes.merge(dimensions_unit: 'cm', weight_unit: 'kg'))
  end
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
