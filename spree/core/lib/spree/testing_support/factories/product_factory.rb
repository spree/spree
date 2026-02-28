FactoryBot.define do
  factory :base_product, class: Spree::Product do
    sequence(:name)   { |n| "Product #{n}#{Kernel.rand(9999)}" }
    description       { generate(:random_description) }
    price             { 19.99 }
    cost_price        { 17.00 }
    sku               { generate(:sku) }
    available_on      { 1.year.ago }
    make_active_at    { 1.year.ago }
    deleted_at        { nil }
    shipping_category { |r| Spree::ShippingCategory.first || r.association(:shipping_category) }
    status            { 'active' }
    stores            { [Spree::Store.default] }

    # ensure stock item will be created for this products master
    # also attach this product to the default store if no stores are passed in
    before(:create) do |_product|
      create(:stock_location) unless Spree::StockLocation.any?
      create(:store, default: true) unless Spree::Store.any?
    end
    after(:create) do |product|
      existing_location_ids = product.master.stock_items.pluck(:stock_location_id)
      Spree::StockLocation.where.not(id: existing_location_ids).find_each do |stock_location|
        stock_location.propagate_variant(product.master)
      end
    end

    factory :custom_product do
      name  { 'Custom Product' }
      price { 17.99 }

      tax_category { |r| Spree::TaxCategory.first || r.association(:tax_category) }
    end

    factory :product do
      tax_category { |r| Spree::TaxCategory.first || r.association(:tax_category) }

      factory :product_in_stock do
        after :create do |product|
          product.master.stock_items.first.adjust_count_on_hand(10)
        end

        trait :without_backorder do
          after :create do |product|
            product.master.stock_items.update_all(backorderable: false)
          end
        end
      end

      factory :product_with_option_types do
        after(:create) { |product| create(:product_option_type, product: product) }
      end
      factory :digital_product do
        track_inventory { false }
        shipping_category { |r| Spree::ShippingCategory.digital || r.association(:digital_shipping_category) }
      end
    end
  end
end
