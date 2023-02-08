FactoryBot.define do
  factory :data_feed_setting, class: Spree::DataFeedSetting do
    id             { 1 }
    enabled        { true }
    store          { create(:store) }
    provider       { 'google' }
    name           { 'test' }
  end
end
