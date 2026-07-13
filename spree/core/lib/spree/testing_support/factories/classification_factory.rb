FactoryBot.define do
  factory :classification, class: Spree::ProductCategory do
    product
    taxon

    position { 1 }
  end
end
