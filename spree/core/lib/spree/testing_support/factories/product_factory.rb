FactoryBot.define do
  # A product with no product-level sku/price. Because those delegated setters
  # are what eagerly build the default variant, an empty product builds none up
  # front — its single default variant is created by +ensure_default_variant+ on
  # create, and supplying nested +variants+ yields exactly those variants. Use
  # this to exercise the true product-creation flow (API shape) without the
  # convenience attributes.
  factory :empty_product, class: Spree::Product do
    sequence(:name)   { |n| "Empty Product #{n}#{Kernel.rand(9999)}" }
    shipping_category { |r| Spree::ShippingCategory.first || r.association(:shipping_category) }
    status            { 'active' }
    store             { Spree::Store.default || association(:store) }

    before(:create) do |_product|
      create(:stock_location) unless Spree::StockLocation.any?
    end
    after(:create) do |product|
      if product.store&.default_channel && product.product_publications.empty?
        Spree::ProductPublication.create!(
          product: product,
          channel: product.store.default_channel,
          published_at: product.available_on,
          unpublished_at: product.discontinue_on
        )
      end
    end
  end

  factory :base_product, class: Spree::Product do
    sequence(:name)   { |n| "Product #{n}#{Kernel.rand(9999)}" }
    description       { generate(:random_description) }
    cost_price        { 17.00 }
    sku               { generate(:sku) }
    deleted_at        { nil }
    shipping_category { |r| Spree::ShippingCategory.first || r.association(:shipping_category) }
    status            { 'active' }
    store             { Spree::Store.default || association(:store) }

    transient do
      price { 19.99 }
      compare_at_price { nil }
      currency { nil }
    end

    before(:create) do |_product|
      create(:stock_location) unless Spree::StockLocation.any?
    end
    after(:create) do |product, evaluator|
      existing_location_ids = product.default_variant.stock_items.pluck(:stock_location_id)
      Spree::StockLocation.where.not(id: existing_location_ids).find_each do |stock_location|
        stock_location.propagate_variant(product.default_variant)
      end

      if evaluator.price.present?
        price_currency = evaluator.currency || product.store&.default_currency || 'USD'
        product.default_variant.set_price(price_currency, evaluator.price, evaluator.compare_at_price)
      end

      # Test convenience only: auto-publish each product on its store's
      # default channel so legacy spec assertions that depend on
      # current-channel visibility (.active, .available, .not_discontinued)
      # keep passing. Production callers must publish explicitly via the
      # Admin SDK / Dashboard create form.
      if product.store&.default_channel && product.product_publications.empty?
        Spree::ProductPublication.create!(
          product: product,
          channel: product.store.default_channel,
          published_at: product.available_on,
          unpublished_at: product.discontinue_on
        )
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
          product.default_variant.stock_items.first.adjust_count_on_hand(10)
        end

        trait :without_backorder do
          after :create do |product|
            product.default_variant.stock_items.update_all(backorderable: false)
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
