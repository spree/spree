Factory.sequence(:tax_category_sequence) {|n| "TaxCategory ##{n}"}

Factory.define(:tax_category) do |record|
  record.name { "TaxCategory - #{rand(999999)}" }
  record.description { Faker::Lorem.sentence }

  record.tax_rates {[TaxRate.new(:amount => 0.05, :calculator => Calculator::Vat.new, :zone => Zone.global)]}
end