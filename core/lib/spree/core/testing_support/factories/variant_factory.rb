FactoryGirl.define do
  factory :variant, :class => Spree::Variant do
    price 19.99
    cost_price 17.00
    sku    { Faker::Lorem.sentence }
    weight { BigDecimal.new("#{rand(200)}.#{rand(99)}") }
    height { BigDecimal.new("#{rand(200)}.#{rand(99)}") }
    width  { BigDecimal.new("#{rand(200)}.#{rand(99)}") }
    depth  { BigDecimal.new("#{rand(200)}.#{rand(99)}") }
    on_hand 5

    # associations:
    product { |p| p.association(:product) }
    option_values { [FactoryGirl.create(:option_value)] }
  end
end
