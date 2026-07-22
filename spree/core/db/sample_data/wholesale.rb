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
  list.description = 'Wholesale pricing for approved B2B buyers (40% off retail) on orders of 10+ per item'
end

# Case-pack minimum: the trade price applies only when a buyer orders at least
# WHOLESALE_MIN_QUANTITY of a single item (VolumeRule matches per line item, not
# per order). Below the threshold the buyer falls back to the retail price — no
# hard checkout block. This is what makes the demo feel like real wholesale.
wholesale_min_quantity = 10

unless price_list.price_rules.any? { |rule| rule.is_a?(Spree::PriceRules::VolumeRule) }
  volume_rule = Spree::PriceRules::VolumeRule.new(price_list: price_list)
  volume_rule.preferred_min_quantity = wholesale_min_quantity
  volume_rule.save!
end

unless price_list.price_rules.any? { |rule| rule.is_a?(Spree::PriceRules::CustomerGroupRule) }
  # price_list must be assigned before the preference — the customer-group-id
  # normalizer resolves groups through rule.store (delegated to price_list).
  rule = Spree::PriceRules::CustomerGroupRule.new(price_list: price_list)
  rule.preferred_customer_group_ids = [wholesale_group.id]
  rule.save!
end

if price_list.prices.none?
  # Same paths the admin UI uses: add_products materializes a blank row per
  # variant × supported currency, then trade prices (40% off that currency's
  # own retail price) fill in wherever a base price exists — rows without one
  # stay blank, exactly as if an admin had added the products by hand.
  price_list.add_products(store.products.ids)

  base_amounts = Spree::Price.where(price_list_id: nil, variant_id: price_list.prices.select(:variant_id))
                             .pluck(:variant_id, :currency, :amount)
                             .each_with_object({}) { |(variant_id, currency, amount), memo| memo[[variant_id, currency]] = amount }

  rows = price_list.prices.pluck(:id, :variant_id, :currency).filter_map do |id, variant_id, currency|
    amount = base_amounts[[variant_id, currency]]
    next if amount.blank?

    { id: id, variant_id: variant_id, currency: currency, amount: (amount * 0.6).round(2) }
  end

  price_list.bulk_update_prices(rows) if rows.any?
end

price_list.activate if price_list.can_activate?
