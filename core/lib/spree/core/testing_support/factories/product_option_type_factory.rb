FactoryGirl.define do
  factory :product_option_type, :class => Spree::ProductOptionType do
    product { Factory(:product) }
    option_type { Factory(:option_type) }
  end
end
