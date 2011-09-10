FactoryGirl.define do
  factory :tracker do
    environment { Rails.env }
    analytics_id 'A100'
    active true
  end
end
