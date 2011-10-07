FactoryGirl.define do
  sequence(:shipping_category_sequence) { |n| "ShippingCategory ##{n}" }

  factory :shipping_category, :class => Spree::ShippingCategory do
    name { Factory.next(:shipping_category_sequence) }
  end
end
