FactoryBot.define do
  factory :collection_exclusion, class: Spree::CollectionExclusion do
    collection
    product { association(:product, store: collection.store) }
  end
end
