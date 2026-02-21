FactoryBot.define do
  factory :market, class: Spree::Market do
    sequence(:name) { |n| "Market #{n}" }
    currency { 'USD' }
    default_locale { 'en' }
    store
    countries { [association(:country)] }

    after(:build) do |market|
      if market.countries.any?
        zone = Spree::Zone.find_or_create_by!(name: 'Test Shipping Zone') do |z|
          z.kind = 'country'
        end
        market.countries.each do |country|
          zone.zone_members.find_or_create_by!(zoneable: country)
        end
        if zone.shipping_methods.empty?
          shipping_category = Spree::ShippingCategory.first || FactoryBot.create(:shipping_category)
          FactoryBot.create(:shipping_method, zones: [zone], shipping_categories: [shipping_category])
        end
      end
    end

    trait :default do
      default { true }
    end

    trait :eu do
      name { 'Europe' }
      currency { 'EUR' }
      default_locale { 'de' }
      tax_inclusive { true }
    end
  end
end
