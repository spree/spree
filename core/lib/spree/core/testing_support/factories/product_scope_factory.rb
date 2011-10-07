FactoryGirl.define do
  factory :product_scope, :class => Spree::ProductScope do
    product_group { Factory(:product_group) }
    name 'on_hand'
    arguments 'some arguments'
  end
end
