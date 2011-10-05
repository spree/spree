FactoryGirl.define do
  sequence :user_authentication_token do |n|
    "xxxx#{Time.now.to_i}#{rand(1000)}#{n}xxxxxxxxxxxxx"
  end

  factory :user do
    email { Faker::Internet.email }
    login { email }
    password 'secret'
    password_confirmation 'secret'
    authentication_token { Factory.next(:user_authentication_token) } if User.attribute_method? :authentication_token
  end

  factory :admin_user, :parent => :user do
    roles { [Role.find_by_name('admin') || Factory(:role, :name => 'admin')]}
  end
end