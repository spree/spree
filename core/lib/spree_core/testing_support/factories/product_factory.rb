FactoryGirl.define do
  sequence(:product_sequence) {|n| "Product ##{n} - #{rand(9999)}"}

  factory :product do
    name { Factory.next(:product_sequence) }
    description { Faker::Lorem.paragraphs(rand(5)+1).join("\n") }

    # associations:
    tax_category {|r| TaxCategory.first || r.association(:tax_category)}
    shipping_category {|r| ShippingCategory.first || r.association(:shipping_category)}

    price 19.99
    cost_price 17.00
    sku 'ABC'
    available_on 1.year.ago
    deleted_at nil
  end

  factory :product_with_option_types, :parent => :product do
    after_create do |product|
      Factory(:product_option_type, :product => product)
    end
  end
end