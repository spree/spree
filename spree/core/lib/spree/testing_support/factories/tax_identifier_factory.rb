FactoryBot.define do
  factory :tax_identifier, class: Spree::TaxIdentifier do
    customer
    kind { 'eu_vat' }
    sequence(:value) { |n| "DE#{123_456_780 + n}" }

    trait :verified do
      validation_status { 'verified' }
      validated_at { Time.current }
      validation_evidence { { 'registry' => 'vies', 'name' => 'Musterfirma GmbH' } }
    end

    # A number entered during checkout, overriding the customer's own.
    trait :on_cart do
      customer { nil }
      cart
    end

    # The frozen snapshot taken when the order was placed.
    trait :on_order do
      customer { nil }
      order
      source { 'customer' }
    end
  end
end
