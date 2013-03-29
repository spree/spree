FactoryGirl.define do
  factory :promotion, class: Spree::Promotion, parent: :activator do
    name 'Promo'
  end
end
