FactoryBot.define do
  factory :invitation, class: Spree::Invitation do
    email { FFaker::Internet.email }
    inviter { create(:admin_user) }
    resource { Spree::Store.default }
    roles { [Spree::Role.find_by(name: 'admin') || create(:role, name: 'admin')] }
  end
end
