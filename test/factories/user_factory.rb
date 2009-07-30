Factory.define(:user) do |record|
  record.email { Faker::Internet.email }
  record.login { Faker::Internet.user_name }
  record.password "spree"
  record.password_confirmation "spree"

  #record.bill_address { Factory(:address) }
  #record.ship_address { Factory(:address) }
end

###### ADD YOUR CODE BELOW THIS LINE #####
