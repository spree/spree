FactoryBot.define do
  factory :delivery, class: Spree::Delivery do
    association :owner, factory: :fulfillment, tracking: nil
    store { owner.store }
    sequence(:tracking_number) { |n| "1Z999AA1012345#{n.to_s.rjust(4, '0')}" }
    status { 'pending' }

    trait :delivered do
      status { 'delivered' }
      delivered_at { Time.current }
    end
  end
end
