FactoryBot.define do
  factory :calculator, class: Spree::Calculator::FlatRate do
    after(:create) { |c| c.set_preference(:amount, 10.0) }
  end

  factory :no_amount_calculator, class: Spree::Calculator::FlatRate do
    after(:create) { |c| c.set_preference(:amount, 0) }
  end

  factory :default_tax_calculator, class: Spree::Calculator::DefaultTax do
  end

  factory :shipping_calculator, class: Spree::Calculator::Shipping::FlatRate do
    preferred_amount { 10.0 }
  end

  factory :shipping_no_amount_calculator, class: Spree::Calculator::Shipping::FlatRate do
    preferred_amount { 0 }
  end

  factory :flat_rate_calculator, class: Spree::Calculator::FlatRate do
    preferred_amount { 10 }
  end

  factory :flat_percent_item_total_calculator, class: Spree::Calculator::FlatPercentItemTotal do
    preferred_flat_percent { 10 }
  end

  factory :non_free_shipping_calculator, class: Spree::Calculator::Shipping::FlatRate do
    after(:create) { |c| c.set_preference(:amount, 20.0) }
  end

  factory :digital_shipping_calculator, class: Spree::Calculator::Shipping::DigitalDelivery do
    after(:create) { |c| c.set_preference(:amount, 0) }
  end
end
