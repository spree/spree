FactoryBot.define do
  factory :user, class: Spree.user_class do
    email                 { generate(:random_email) }
    login                 { email }
    password              { 'secret' }
    password_confirmation { password }

    first_name { FFaker::Name.first_name }
    last_name  { FFaker::Name.last_name }

    public_metadata { {} }
    private_metadata { {} }

    factory :user_with_addresses, aliases: [:user_with_addreses] do
      after(:create) do |user|
        user.ship_address = create(:address, user: user)
        user.bill_address = create(:address, user: user)
        user.addresses << user.ship_address
        user.addresses << user.bill_address
        user.save
      end
    end
  end

  factory :admin_user, class: Spree.admin_user_class do
    email                 { generate(:random_email) }
    login                 { email }
    password              { 'secret' }
    password_confirmation { password }
    first_name { FFaker::Name.first_name }
    last_name  { FFaker::Name.last_name }

    transient do
      without_admin_role { false }
    end

    trait :without_admin_role do
      without_admin_role { true }
    end

    after(:create) do |user, evaluator|
      unless evaluator.without_admin_role
        admin_role = Spree::Role.default_admin_role
        create(:role_user, user: user, role: admin_role) unless user.has_spree_role?(admin_role.name)
      end
    end
  end
end
