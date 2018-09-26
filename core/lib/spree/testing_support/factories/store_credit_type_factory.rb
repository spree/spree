FactoryBot.define do
  factory :primary_credit_type, class: Spree::StoreCreditType do
    name      { Spree::StoreCreditType::DEFAULT_TYPE_NAME }
    priority  { '1' }
  end

  factory :secondary_credit_type, class: Spree::StoreCreditType do
    name      { 'Non-expiring' }
    priority  { '2' }
  end
end
