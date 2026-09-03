FactoryBot.define do
  factory :catalog, class: Spree::Catalog do
    sequence(:name) { |n| "Wholesale Catalog #{n}" }
    store { Spree::Store.default || create(:store) }
    # A catalog is born inactive and goes live through Catalogs::Activate, but
    # a spec that builds one almost always wants an agreement that applies —
    # `:inactive` is the trait for testing the other side.
    active { true }

    trait :inactive do
      active { false }
    end
  end

  factory :catalog_product, class: Spree::CatalogProduct do
    catalog
    product { association(:product, store: catalog.store) }
  end

  factory :catalog_assignment, class: Spree::CatalogAssignment do
    catalog
    assignable { association(:company, store: catalog.store) }
  end

  factory :catalog_quantity_rule, class: Spree::CatalogQuantityRule do
    catalog
    variant { association(:variant, product: association(:product, store: catalog.store)) }
    minimum_order_quantity { 48 }
    order_multiple { 24 }
  end

  factory :catalog_order_minimum, class: Spree::CatalogOrderMinimum do
    catalog
    currency { 'USD' }
    amount { 500 }
  end
end
