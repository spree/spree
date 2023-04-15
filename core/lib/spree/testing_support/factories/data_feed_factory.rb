FactoryBot.define do
  factory :data_feed, class: Spree::DataFeed do
    id             { 1 }
    active         { true }
    store          { create(:store) }
    provider       { 'google' }
    name           { 'test' }
  end
end
