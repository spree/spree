FactoryBot.define do
  # :classification is the pre-6.0 name, kept as an alias of the renamed :product_category.
  factory :product_category, class: Spree::ProductCategory, aliases: [:classification] do
    product
    category

    position { 1 }
  end
end
