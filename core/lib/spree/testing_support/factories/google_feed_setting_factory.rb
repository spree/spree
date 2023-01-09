FactoryBot.define do
  factory :google_feed_setting, class: Spree::GoogleFeedSetting do
    store    { create(:store) }
    id       { 1 }
    brand    { true }
    material { false }
    color    { true }
    size     { false }
  end
end
