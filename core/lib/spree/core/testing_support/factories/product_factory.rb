FactoryGirl.define do
  sequence(:product_sequence) { |n| "Product ##{n} - #{rand(9999)}" }

  factory :simple_product, :class => Spree::Product do
    name { FactoryGirl.generate :product_sequence }
    description { Faker::Lorem.paragraphs(1 + Kernel.rand(5)).join("\n") }
    price 19.99
    cost_price 17.00
    sku 'ABC'
    available_on 1.year.ago
    deleted_at nil
  end

  factory :product, :parent => :simple_product do
    tax_category { |r| Spree::TaxCategory.find(:first) || r.association(:tax_category) }
    shipping_category { |r| Spree::ShippingCategory.find(:first) || r.association(:shipping_category) }
  end

  factory :product_with_option_types, :parent => :product do
    after_create { |product| Factory(:product_option_type, :product => product) }
  end

  factory :custom_product, :class => Spree::Product do
    name "Custom Product"
    price "17.99"
    description { Faker::Lorem.paragraphs(1 + Kernel.rand(5)).join("\n") }

    # associations:
    tax_category { |r| Spree::TaxCategory.find(:first) || r.association(:tax_category) }
    shipping_category { |r| Spree::ShippingCategory.find(:first) || r.association(:shipping_category) }

    sku 'ABC'
    available_on 1.year.ago
    deleted_at nil

    association :taxons
  end
end
