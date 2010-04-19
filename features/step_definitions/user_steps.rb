Given /^I am signed up as "([^\"]*)"$/ do |email_and_password|
  email, password = email_and_password.split("/")
  @me = Factory(:user,
                :email => email,
                :login => email,
                :password => password,
                :password_confirmation => password,
                :bill_address => Factory(:address),
                :ship_address => Factory(:address))
end

When /^(?:|I )sign in as "([^\"]*)"$/ do |email_and_password|
  email, password = email_and_password.split("/")

  visit login_path

  fill_in "Email",    :with => email
  fill_in "Password", :with => password

  click_button "Log In"
end


When /^(?:|I )fill (billing|shipping) address with correct data$/ do |address_type|
  str_addr = address_type[0...4] + "_address"
  address = @me ? @me.send(str_addr) : Factory(:address)
  When %{I select "United States" from "Country" within "fieldset##{address_type}"}
  ['firstname', 'lastname', 'address1', 'city', 'state_name', 'zipcode', 'phone'].each do |field|
    When %{I fill in "checkout_#{str_addr}_attributes_#{field}" with "#{address.send(field)}"}
  end
end

When /^(?:|I )add a product with (.*?)? to cart$/ do |captured_fields|
  fields = {'name' => "RoR Mug", 'count_on_hand' => '10', 'available_on' => "2010-03-06 18:48:21", 'price' => "14.99"}
  captured_fields.split(/,\s+/).each do |field|
    (name, value) = field.split(/:\s*/, 2)
    fields[name] = value.delete('"')
  end
  price = fields.delete('price')
  if Product.master_price_equals(price).count(:conditions => fields) == 0
    Factory(:product, fields.merge('price' => price))
  end
  When %{I go to the products page}
  Then %{I should see "#{fields['name']}" within "ul.product-listing"}
  When %{I follow "#{fields['name']}"}
  Then %{I should see "#{fields['name']}" within "h1"}
  And  %{I should see "$#{price}" within "span.price"}
  When %{I press "Add To Cart"}
end

When /^I choose "(.*?)" as shipping method and "(.*?)" as payment method$/ do |shiping_method, payment_method|
  When %{I choose "#{shiping_method}"}
  And %{press "Save and Continue"}
  Then %{I should see "Payment Information" within "legend"}

  When %{I choose "#{payment_method}"}
  And %{press "Save and Continue"}
  Then %{I should see "Confirm" within "legend"}

  When %{I press "Place Order"}
end

Then /^cart should be empty$/ do
  Then %{I should not see "Cart: ("}
end


