FactoryGirl.define do
  sequence(:shipping_category_sequence) {|n| "ShippingCategory ##{n}"}

  factory :shipping_category do
    name { Factory.next(:shipping_category_sequence) }
  end
end