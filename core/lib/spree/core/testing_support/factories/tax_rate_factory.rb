FactoryGirl.define do
  factory :tax_rate, :class => Spree::TaxRate do
    zone { Factory(:zone) }
    amount 100.00
    tax_category { Factory(:tax_category) }
  end
end
