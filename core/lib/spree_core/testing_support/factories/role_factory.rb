FactoryGirl.define do
  sequence(:role_sequence) {|n| "Role ##{n}"}

  factory :role do
    name { Factory.next(:role_sequence) }
  end

  factory :admin_role, :parent => :role do
    name 'admin'
  end
end