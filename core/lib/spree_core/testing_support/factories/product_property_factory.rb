FactoryGirl.define do
  factory :product_property do
    product { Factory(:product) }
    property { Factory(:property) }
  end
end