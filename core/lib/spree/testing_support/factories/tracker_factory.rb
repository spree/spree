FactoryGirl.define do
  factory :tracker, class: Spree::Tracker do
    analytics_id 'A100'
    active true
  end
end
