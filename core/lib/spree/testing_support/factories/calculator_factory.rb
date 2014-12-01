FactoryGirl.define do
  factory :calculator, class: Spree::Calculator::FlatRate do
    after(:create) { |c| c.set_preference(:amount, 10.0) }
  end

  factory :no_amount_calculator, class: Spree::Calculator::FlatRate do
    after(:create) { |c| c.set_preference(:amount, 0) }
  end

  factory :default_tax_calculator, class: Spree::Calculator::DefaultTax do
  end

  factory :shipping_calculator, class: Spree::Calculator::Shipping::FlatRate do
    after(:create) { |c| c.set_preference(:amount, 10.0) }
  end

  factory :shipping_no_amount_calculator, class: Spree::Calculator::Shipping::FlatRate do
    after(:create) { |c| c.set_preference(:amount, 0) }
  end
end
