FactoryGirl.define do
  factory :tax_rate do
    zone { Factory(:zone) }
    amount 100.00
    tax_category { Factory(:tax_category) }
  end
end