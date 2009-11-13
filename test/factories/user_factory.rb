Factory.define(:user) do |record|
  record.email { Faker::Internet.email }
  record.login { Factory.next(:login) }
  record.password "spree"
  record.password_confirmation "spree"

  #record.bill_address { Factory(:address) }
  #record.ship_address { Factory(:address) }
end

Factory.sequence :login do |n|
  Faker::Internet.user_name + n.to_s
end

###### ADD YOUR CODE BELOW THIS LINE #####

Factory.define(:admin_user, :parent => :user) do |u|
  u.roles { [Role.find_by_name("admin") || Factory(:admin_role)]}
end
