FactoryBot.define do
  factory :event, class: Spree::Webhooks::Event do
    enabled { true }
    name { 'resource.create' }
  end
end
