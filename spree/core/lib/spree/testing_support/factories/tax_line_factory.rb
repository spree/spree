FactoryBot.define do
  factory :tax_line, class: Spree::TaxLine do
    line_item
    order { line_item&.order || fulfillment&.order }
    tax_rate

    amount { 10.0 }
    label { 'VAT 5%' }
    included { false }

    trait :for_fulfillment do
      line_item { nil }
      association(:fulfillment, factory: :shipment)
    end

    trait :included_in_price do
      included { true }
    end
  end
end
