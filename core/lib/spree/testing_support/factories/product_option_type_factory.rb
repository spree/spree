FactoryGirl.define do
  factory :product_option_type, class: Spree::ProductOptionType do
    product
    option_type
  end
end
