FactoryBot.define do
  factory :catalog, class: Spree::Catalog do
    sequence(:name) { |n| "Wholesale Catalog #{n}" }
    store { Spree::Store.default || create(:store) }
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
