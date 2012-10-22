FactoryGirl.define do
  factory :calculator, :class => Spree::Calculator::FlatRate do
    after_create { |c| c.set_preference(:amount, 10.0) }
  end

  factory :no_amount_calculator, :class => Spree::Calculator::FlatRate do
    after_create { |c| c.set_preference(:amount, 0) }
  end
end
