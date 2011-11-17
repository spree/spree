require 'spec_helper'

describe "Sign Out" do
  it "should allow a signed in user to logout" do
    user = Factory(:user, :email => "email@person.com", :password => "secret", :password_confirmation => "secret")
    visit spree.login_path
    fill_in "user_email", :with => user.email
    fill_in "user_password", :with => user.password
    click_button "Log In"
    click_link "Logout"
    visit spree.root_path
    page.should have_content("Log In")
    page.should_not have_content("Logout")
  end
end
