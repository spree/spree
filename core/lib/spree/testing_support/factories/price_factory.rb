FactoryBot.define do
  factory :price, class: Spree::Price do
    variant
    amount   { 19.99 }
    currency { 'USD' }
  end
end
