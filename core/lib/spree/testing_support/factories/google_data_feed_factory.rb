FactoryBot.define do
  factory :google_data_feed, class: Spree::DataFeed::Google do
    id             { 1 }
    active         { true }
    store          { create(:store) }
    name           { 'test' }
  end
end
