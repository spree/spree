# Three collections that between them exercise both membership models: two
# rule-based (they regenerate themselves) and one hand-curated with a dynamic
# sort. Runs after the product import so there is a catalog to draw from.
store = Spree::Store.default

# Each automatic collection is defined by the single rule that materializes it.
automatic_collections = [
  {
    permalink: 'new-arrivals',
    name: 'New Arrivals',
    sort_order: 'available_on desc',
    rule_type: 'Spree::CollectionRules::AvailableOn',
    # Days back the window reaches.
    rule_value: '30'
  },
  {
    permalink: 'on-sale',
    name: 'On Sale',
    sort_order: 'price asc',
    rule_type: 'Spree::CollectionRules::Sale',
    rule_value: 'true'
  }
]

automatic_collections.each do |attributes|
  collection = store.collections.find_or_initialize_by(permalink: attributes[:permalink])
  collection.name = attributes[:name]
  collection.automatic = true
  collection.rules_match_policy = 'all'
  collection.sort_order = attributes[:sort_order]
  collection.save!

  unless collection.rules.exists?(type: attributes[:rule_type])
    collection.rules.create!(
      type: attributes[:rule_type],
      value: attributes[:rule_value],
      match_policy: 'is_equal_to'
    )
  end

  collection.regenerate_products
end

# Manual: "best selling" is a sort, not a membership rule, so this is a curated
# shelf the merchant controls, ordered by actual sales. Seeded with a slice of
# the catalog to demonstrate curation.
best_sellers = store.collections.find_or_initialize_by(permalink: 'best-sellers')
best_sellers.name = 'Best Sellers'
best_sellers.automatic = false
best_sellers.sort_order = 'best_selling'
best_sellers.save!

if best_sellers.products.empty?
  Spree::Collections::AddProducts.call(
    collections: [best_sellers],
    products: store.products.order(:id).limit(12)
  )
end
