FactoryBot.define do
  factory :data_feed_setting, class: Spree::DataFeedSetting do
    id             { 1 }
    enabled         { true }
  end
end
