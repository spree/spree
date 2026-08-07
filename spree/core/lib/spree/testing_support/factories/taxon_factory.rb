FactoryBot.define do
  # @deprecated Use :category. Kept so existing extension and application suites
  #   keep passing through the 6.0 rename; removed in 6.1 with Spree::Taxon.
  #
  # A category is store-owned via store_id, so this creates no taxonomy. Callers
  # that need a legacy taxonomy-backed row pass `taxonomy:` explicitly.
  factory :taxon, parent: :category do
    sequence(:name) { |n| "taxon_#{n}" }
  end
end
