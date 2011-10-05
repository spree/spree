FactoryGirl.define do
  factory :mail_method do
    environment { Rails.env }
    active true
  end
end
