FactoryGirl.define do
  factory :tax_category, :class => Spree::TaxCategory do
    name { "TaxCategory - #{rand(999999)}" }
    description { Faker::Lorem.sentence }

    after_create do |tax_category|
      tax_category.tax_rates.create!(:amount => 0.05, :calculator => Spree::Calculator::DefaultTax.new, :zone => Spree::Zone.global)
    end
  end
end
