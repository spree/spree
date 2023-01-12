FactoryBot.define do
  factory :google_feed_setting, class: Spree::GoogleFeedSetting do
    store          { Spree::Store.find(1) }
    #spree_store_id { 1 }
    id             { 1 }
    brand          { true }
    material       { false }
    color          { true }
    size           { false }
  end
end
