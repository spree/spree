FactoryGirl.define do
  factory :tax_category, :class => Spree::TaxCategory do
    name { "TaxCategory - #{rand(999999)}" }
    description { Faker::Lorem.sentence }

    tax_rates { [Spree::TaxRate.new(:amount => 0.05, :calculator => Spree::Calculator::Vat.new, :zone => Zone.global)] }
  end
end
