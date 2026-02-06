FactoryBot.define do
  factory :invitation, class: Spree::Invitation do
    email { FFaker::Internet.email }
    association :inviter, factory: :admin_user
  end
end
