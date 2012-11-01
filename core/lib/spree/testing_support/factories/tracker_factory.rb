FactoryGirl.define do
  factory :tracker, :class => Spree::Tracker do
    environment { Rails.env }
    analytics_id 'A100'
    active true
  end
end
