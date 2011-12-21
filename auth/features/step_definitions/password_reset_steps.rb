
When /^I reset my password$/ do
  user = User.find_by_email("email@person.com")
  user.send_reset_password_instructions
  
  visit edit_user_password_path(:reset_password_token => user.reset_password_token) 
  fill_in "user[password]", :with => 'abc123'
  fill_in "user[password_confirmation]", :with => 'abc123'
  click_button "Update my password and log me in"
end



