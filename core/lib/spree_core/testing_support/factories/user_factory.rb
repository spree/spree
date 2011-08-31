FactoryGirl.define do
  sequence(:login) {|n| Faker::Internet.user_name + n.to_s}
  sequence(:user_authentication_token) {|n| "xxxx#{Time.now.to_i}#{rand(1000)}#{n}xxxxxxxxxxxxx"}

  factory :user do
    email { Faker::Internet.email }
    login { |u| u.email }
    password 'secret'
    password_confirmation 'secret'
    authentication_token { Factory.next(:user_authentication_token) } if User.attribute_method? :authentication_token
  end

  factory :admin_user, :parent => :user do
    roles { [Role.find_by_name("admin") || Factory(:role, :name => 'admin')]}
  end
end