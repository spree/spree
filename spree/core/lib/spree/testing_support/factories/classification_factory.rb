FactoryBot.define do
  factory :classification, class: Spree::Classification do
    product
    taxon

    position { 1 }
  end
end
