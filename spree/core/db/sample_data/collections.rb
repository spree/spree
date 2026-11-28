# Three collections that between them exercise both membership models: two
# rule-based (they regenerate themselves) and one hand-curated with a dynamic
# sort. Runs after the product import so there is a catalog to draw from.
store = Spree::Current.store

# Updated on a re-run; otherwise created through the workflow, which publishes
# it on every active channel.
find_or_create_collection = lambda do |attributes|
  existing = store.collections.find_by(permalink: attributes[:permalink])
  next existing.tap { |collection| collection.update!(attributes) } if existing

  result = Spree.collection_create_workflow.call(store: store, attributes: attributes)
  raise result.error.to_s if result.failure?

  result.value
end

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
  collection = find_or_create_collection.call(attributes.slice(:permalink, :name, :sort_order).merge(rules_match_policy: 'all'))

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
best_sellers = find_or_create_collection.call(permalink: 'best-sellers', name: 'Best Sellers', sort_order: 'best_selling')

if best_sellers.products.empty?
  Spree::Collections::AddProducts.call(
    collections: [best_sellers],
    products: store.products.order(:id).limit(12)
  )
end
