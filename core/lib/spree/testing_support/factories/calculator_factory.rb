FactoryBot.define do
  factory :calculator, class: Spree::Calculator::Promotion::FlatRate do
    after(:create) { |c| c.set_preference(:amount, 10.0) }
  end

  factory :no_amount_calculator, class: Spree::Calculator::Promotion::FlatRate do
    after(:create) { |c| c.set_preference(:amount, 0) }
  end

  factory :default_tax_calculator, class: Spree::Calculator::Tax::DefaultTax do
  end

  factory :shipping_calculator, class: Spree::Calculator::Shipping::FlatRate do
    after(:create) { |c| c.set_preference(:amount, 10.0) }
  end

  factory :shipping_no_amount_calculator, class: Spree::Calculator::Shipping::FlatRate do
    after(:create) { |c| c.set_preference(:amount, 0) }
  end
end
