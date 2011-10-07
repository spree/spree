FactoryGirl.define do
  factory :mail_method, :class => Spree::MailMethod do
    environment { Rails.env }
    active true
  end
end
