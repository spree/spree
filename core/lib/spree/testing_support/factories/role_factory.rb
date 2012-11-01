FactoryGirl.define do
  sequence(:role_sequence) { |n| "Role ##{n}" }

  factory :role, :class => Spree::Role do
    name { FactoryGirl.generate :role_sequence }
  end

  factory :admin_role, :parent => :role do
    name 'admin'
  end
end
