FactoryBot.define do
  factory :tax_rate, class: Spree::TaxRate do
    zone
    tax_category
    amount { 0.1 }

    association(:calculator, factory: :default_tax_calculator)
  end
end
