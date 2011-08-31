FactoryGirl.define do
  sequence(:tax_category_sequence) {|n| "TaxCategory ##{n}"}

  factory :tax_category do
    name { "TaxCategory - #{rand(999999)}" }
    description { Faker::Lorem.sentence }

    tax_rates {[TaxRate.new(:amount => 0.05, :calculator => Calculator::Vat.new, :zone => Zone.global)]}
  end
end