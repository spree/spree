FactoryBot.define do
  factory :endpoint, class: Spree::Webhooks::Endpoint do
    enabled { true }
    url { 'https://google.com:81/' }
  end
end
