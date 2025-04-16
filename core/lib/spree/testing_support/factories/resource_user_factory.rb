FactoryBot.define do
  factory :resource_user, class: Spree::ResourceUser do
    association :resource, factory: :store
    user do
      create(:admin_user, skip_resource_user: true)
    end
  end
end
