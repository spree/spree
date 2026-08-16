FactoryBot.define do
  factory :role, class: Spree::Role do
    sequence(:name) { |n| "Role #{n}" }
    resource { Spree::Store.default || create(:store) }

    factory :admin_role do
      name { 'admin' }
    end
  end
end
