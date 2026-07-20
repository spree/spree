# Wholesale demo setup on top of the gated channel seeded by
# Spree::Seeds::Channels: an approved demo buyer and a customer-group price
# list, so a fresh install can walk the whole B2B portal story — sign in as
# the buyer, see wholesale prices, check out on the wholesale channel.
store = Spree::Store.default

wholesale_group = store.customer_groups.find_or_create_by!(name: Spree::Seeds::CustomerGroups::WHOLESALE_NAME)

buyer = Spree.user_class.find_by(email: 'wholesale@example.com')
if buyer.nil?
  buyer = Spree.user_class.new(
    email: 'wholesale@example.com',
    password: 'spree123',
    password_confirmation: 'spree123',
    first_name: 'Wanda',
    last_name: 'Wholesale'
  )
  buyer.save!
end
wholesale_group.add_customers([buyer.id])

price_list = store.price_lists.find_or_create_by!(name: 'Wholesale') do |list|
  list.description = 'Wholesale pricing for approved B2B buyers (40% off retail)'
end

unless price_list.price_rules.any? { |rule| rule.is_a?(Spree::PriceRules::CustomerGroupRule) }
  # price_list must be assigned before the preference — the customer-group-id
  # normalizer resolves groups through rule.store (delegated to price_list).
  rule = Spree::PriceRules::CustomerGroupRule.new(price_list: price_list)
  rule.preferred_customer_group_ids = [wholesale_group.id]
  rule.save!
end

if price_list.prices.none?
  currency = store.default_currency
  now = Time.current
  rows = Spree::Variant.joins(:product)
                       .where(spree_products: { store_id: store.id })
                       .joins(:prices)
                       .where(spree_prices: { currency: currency, price_list_id: nil })
                       .pluck(:id, Spree::Price.arel_table[:amount])
                       .to_h # one row per variant — last base price wins
                       .filter_map do |variant_id, amount|
    next if amount.blank?

    {
      variant_id: variant_id,
      price_list_id: price_list.id,
      amount: (amount * 0.6).round(2),
      currency: currency,
      created_at: now,
      updated_at: now
    }
  end

  Spree::Price.insert_all(rows) if rows.any?
end

price_list.activate if price_list.can_activate?
