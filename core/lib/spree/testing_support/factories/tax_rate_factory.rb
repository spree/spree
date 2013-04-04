FactoryGirl.define do
  factory :tax_rate, class: Spree::TaxRate do
    zone
    amount 100.00
    tax_category
    # association(:calculator, factory: :default_tax_calculator, strategy: :build)
  end
end
