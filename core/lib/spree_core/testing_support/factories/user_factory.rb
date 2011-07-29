Factory.sequence :login do |n|
  Faker::Internet.user_name + n.to_s
end

Factory.sequence :user_authentication_token do |n|
  "xxxx#{Time.now.to_i}#{rand(1000)}#{n}xxxxxxxxxxxxx"
end

Factory.define :user do |f|
  f.email { Faker::Internet.email }
  f.login { |u| u.email }
  f.password "secret"
  f.password_confirmation "secret"
  f.authentication_token { Factory.next(:user_authentication_token) } if User.attribute_method? :authentication_token
end

Factory.define(:admin_user, :parent => :user) do |u|
  u.roles { [Role.find_by_name("admin") || Factory(:role, :name => "admin")]}
end
