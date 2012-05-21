FactoryGirl.define do
  factory :product_property, :class => Spree::ProductProperty do
    product { Factory(:product) }
    property { Factory(:property) }
    value 'blue'
  end
end
