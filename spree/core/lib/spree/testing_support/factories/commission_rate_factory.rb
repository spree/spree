FactoryBot.define do
  factory :commission_rate, class: Spree::CommissionRate do
    sequence(:name) { |n| "Commission rate #{n}" }
    store { Spree::Store.default || create(:store) }
    kind { 'percentage' }
    value { 10 }
    enabled { true }

    trait :fixed do
      kind { 'fixed' }
      value { 2.5 }
      currency { 'USD' }
    end

    trait :disabled do
      enabled { false }
    end

    trait :with_shipping do
      include_shipping { true }
    end

    trait :gross_base do
      tax_inclusive { true }
    end
  end

  factory :commission_rule, class: Spree::CommissionRule do
    commission_rate { create(:commission_rate) }
    subject { create(:vendor) }
  end

  factory :commission_line, class: Spree::CommissionLine do
    order { create(:order) }
    vendor { create(:vendor) }
    line_item { create(:line_item) }
    kind { 'percentage' }
    rate { 10 }
    amount { 10 }
    tax_amount { 0 }
    total { 10 }
    currency { 'USD' }
  end
end
