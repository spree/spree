FactoryGirl.define do
  factory :product_scope do
    product_group { Factory(:product_group) }
    name 'on_hand'
    arguments 'some arguments'
  end
end