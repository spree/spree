FactoryGirl.define do
  factory :tax_rate, :class => Spree::TaxRate do
    zone { FactoryGirl.create(:zone) }
    amount 100.00
    tax_category { FactoryGirl.create(:tax_category) }
  end
end
