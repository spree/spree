FactoryGirl.define do
  factory :tax_rate, class: Spree::TaxRate do
    sequence(:name) { |n| "Tax Rate #{n}" }
    zone
    amount 0.1
    tax_category
    association(:calculator, factory: :default_tax_calculator)
  end
end
