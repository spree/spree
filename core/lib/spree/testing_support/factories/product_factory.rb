FactoryGirl.define do
  factory :base_product, class: Spree::Product do
    sequence(:name) { |n| "Product ##{n} - #{Kernel.rand(9999)}" }
    description { generate(:random_description) }
    price 19.99
    cost_price 17.00
    sku 'ABC'
    available_on { 1.year.ago }
    deleted_at nil

    # ensure stock item will be created for this products master
    before(:create) { create(:stock_location) if Spree::StockLocation.count == 0 }

    factory :product do
      tax_category { |r| Spree::TaxCategory.first || r.association(:tax_category) }
      shipping_category { |r| Spree::ShippingCategory.first || r.association(:shipping_category) }

      factory :product_with_option_types do
        after(:create) { |product| create(:product_option_type, product: product) }
      end
    end
  end

  factory :custom_product, class: Spree::Product do
    name 'Custom Product'
    description { generate(:random_description) }
    price 17.99
    sku 'ABC'
    available_on { 1.year.ago }
    deleted_at nil

    tax_category { |r| Spree::TaxCategory.first || r.association(:tax_category) }
    shipping_category { |r| Spree::ShippingCategory.first || r.association(:shipping_category) }

    # association :taxons

    # ensure stock item will be created for this products master
    before(:create) { create(:stock_location) if Spree::StockLocation.count == 0 }
  end
end
