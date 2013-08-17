FactoryGirl.define do
  factory :base_variant, :class => Spree::Variant do
    price 19.99
    cost_price 17.00
    sku    { SecureRandom.hex }
    weight { BigDecimal.new("#{rand(200)}.#{rand(99)}") }
    height { BigDecimal.new("#{rand(200)}.#{rand(99)}") }
    width  { BigDecimal.new("#{rand(200)}.#{rand(99)}") }
    depth  { BigDecimal.new("#{rand(200)}.#{rand(99)}") }

    # associations:
    product { |p| p.association(:base_product) }
    option_values { [FactoryGirl.create(:option_value)] }
  end

  factory :variant, :parent => :base_variant do
    if Spree::Config[:track_inventory_levels]
      on_hand 5
    end

    # associations:
    product { |p| p.association(:product) }
  end
end
