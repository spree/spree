FactoryBot.define do
  factory :market, class: Spree::Market do
    sequence(:name) { |n| "Market #{n}" }
    currency { 'USD' }
    default_locale { 'en' }
    store
    countries { [create(:country)] }

    after(:build) do |market|
      # Delivery methods are worldwide by default (no zones), so serving the
      # market's countries only requires that a method exists at all.
      if market.countries.any? && !Spree::DeliveryMethod.where(delivery_zone_id: nil).exists?
        FactoryBot.create(:delivery_method)
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
