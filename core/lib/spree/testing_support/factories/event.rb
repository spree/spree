FactoryBot.define do
  factory :event, class: Spree::Webhooks::Event do
    enabled { true }
    name { 'order.create' }
  end
end
