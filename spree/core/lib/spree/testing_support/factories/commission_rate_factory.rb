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

  # Reference lists go through the preference writers, so ids are
  # scope-checked in specs exactly as they are through the API.
  factory :commission_vendor_rule, class: Spree::CommissionRules::VendorRule do
    commission_rate { create(:commission_rate) }
    transient { vendors { [] } }

    after(:build) do |rule, evaluator|
      rule.preferred_vendor_ids = Array(evaluator.vendors).map(&:id) if evaluator.vendors.present?
    end
  end

  factory :commission_category_rule, class: Spree::CommissionRules::CategoryRule do
    commission_rate { create(:commission_rate) }
    transient { categories { [] } }

    after(:build) do |rule, evaluator|
      rule.preferred_category_ids = Array(evaluator.categories).map(&:id) if evaluator.categories.present?
    end
  end

  factory :commission_product_rule, class: Spree::CommissionRules::ProductRule do
    commission_rate { create(:commission_rate) }
    transient { products { [] } }

    after(:create) do |rule, evaluator|
      rule.products = Array(evaluator.products) if evaluator.products.present?
    end
  end

  factory :commission_item_total_rule, class: Spree::CommissionRules::ItemTotalRule do
    commission_rate { create(:commission_rate) }
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
