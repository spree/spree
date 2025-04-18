FactoryBot.define do
  factory :invitation, class: Spree::Invitation do
    email { FFaker::Internet.email }
    inviter { create(:admin_user) }
  end
end
