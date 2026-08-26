FactoryBot.define do
  factory :tax_identifier, class: Spree::TaxIdentifier do
    owner factory: :customer
    kind { 'eu_vat' }
    # Real enough to survive the format check core applies to eu_vat.
    sequence(:value) { |n| TaxIdentifierValidatorHelpers.eu_vat_number(n) }

    trait :verified do
      validation_status { 'verified' }
      validated_at { Time.current }
      validation_evidence { { 'registry' => 'vies', 'name' => 'Musterfirma GmbH' } }
    end

    # A number entered during checkout, overriding the customer's own.
    trait :on_cart do
      owner factory: :cart
    end

    # The frozen snapshot taken when the order was placed.
    trait :on_order do
      owner factory: :order
      source { 'customer' }
    end

    trait :on_company do
      owner factory: :company
    end

    trait :on_seller do
      owner factory: :seller
    end
  end
end
