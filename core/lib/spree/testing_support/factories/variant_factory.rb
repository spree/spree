FactoryBot.define do
  sequence(:random_float) { BigDecimal("#{rand(200)}.#{rand(99)}") }

  factory :base_variant, class: Spree::Variant do
    price           { 19.99 }
    cost_price      { 17.00 }
    sku             { generate(:sku) }
    weight          { generate(:random_float) }
    height          { generate(:random_float) }
    width           { generate(:random_float) }
    depth           { generate(:random_float) }
    is_master       { 0 }
    track_inventory { true }

    product       { |p| p.association(:base_product, stores: [Spree::Store.default]) }
    option_values { [build(:option_value)] }

    transient do
      create_stock { true }
    end

    # ensure stock item will be created for this variant
    before(:create) do |variant, evaluator|
      create(:stock_location) if evaluator.create_stock && !Spree::StockLocation.any?
    end

    after(:create) do |variant, evaluator|
      if evaluator.create_stock
        existing_location_ids = variant.stock_items.pluck(:stock_location_id)
        Spree::StockLocation.where.not(id: existing_location_ids).find_each do |stock_location|
          stock_location.propagate_variant(variant)
        end
      end
    end

    factory :variant do
      # on_hand 5
      product { |p| p.association(:product, stores: [Spree::Store.default]) }

      factory :with_image_variant do
        images { create_list(:image, 1) }
      end

      trait :with_no_price do
        price { nil }
        cost_price { nil }
        currency { nil }
      end
    end

    factory :master_variant do
      is_master { 1 }
    end

    factory :on_demand_variant do
      track_inventory { false }

      factory :on_demand_master_variant do
        is_master { 1 }
      end
    end
  end
end
