FactoryBot.define do
  factory :google_data_feed, class: Spree::DataFeed::Google do
    active         { true }
    association :store, factory: :store
    name           { 'test' }
  end
end
