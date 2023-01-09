FactoryBot.define do
  factory :google_feed_setting, class: Spree::GoogleFeedSetting do
    id             { 1 }
    brand          { true }
  end
end
