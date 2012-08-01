FactoryGirl.define do
  factory :tax_category, :class => Spree::TaxCategory do
    name { "TaxCategory - #{rand(999999)}" }
    description { Faker::Lorem.sentence }
  end

  factory :tax_category_with_rates, :parent => :tax_category do
    after_create do |tax_category|
      tax_category.tax_rates.build(:amount => 0.05, :calculator => Spree::Calculator::DefaultTax.new) do |r|
        r.zone = Spree::Zone.find_by_name('GlobalZone') || FactoryGirl.create(:global_zone)
      end.save!
    end
  end
  
end
