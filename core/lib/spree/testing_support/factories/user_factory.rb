FactoryBot.define do
  factory :user, class: Spree.user_class do
    email                 { generate(:random_email) }
    login                 { email }
    password              { 'secret' }
    password_confirmation { password }

    first_name { FFaker::Name.first_name } if Spree.user_class.attribute_method?(:first_name)
    last_name  { FFaker::Name.last_name } if Spree.user_class.attribute_method?(:last_name)

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

    spree_roles { [Spree::Role.find_by(name: 'admin') || create(:role, name: 'admin')] }
  end
end
