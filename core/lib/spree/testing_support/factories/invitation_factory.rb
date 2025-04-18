FactoryBot.define do
  factory :invitation, class: Spree::Invitation do
    email { FFaker::Internet.email }
    inviter { Spree::Store.default.users.first || create(:admin_user) }
    resource { Spree::Store.default }
    role { Spree::Role.default_admin_role }
  end
end
