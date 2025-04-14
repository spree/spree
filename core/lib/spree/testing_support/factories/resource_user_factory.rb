FactoryBot.define do
  factory :resource_user, class: Spree::ResourceUser do
    association :resource, factory: :store
    association :user, factory: :admin_user
  end
end
