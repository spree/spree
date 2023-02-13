FactoryBot.define do
  factory :product_translation, class: Spree::Product::Translation do
    sequence(:name) { |n| "Product #{n}#{Kernel.rand(9999)}" }
    description { generate(:random_description) }
  end
end
