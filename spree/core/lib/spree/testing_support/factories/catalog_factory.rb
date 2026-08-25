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
end
