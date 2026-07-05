FactoryBot.define do
  factory :channel, class: Spree::Channel do
    store { Spree::Store.default || association(:store) }
    sequence(:name) { |n| "Channel #{n}" }
    sequence(:code) { |n| "channel_#{n}" }
    active { true }
  end
end
