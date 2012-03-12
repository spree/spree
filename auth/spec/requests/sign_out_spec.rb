require 'spec_helper'

describe "Sign Out" do
  let!(:user) do
   Factory(:user,
          :email => "email@person.com",
          :password => "secret",
          :password_confirmation => "secret")
  end

  before do
    visit spree.login_path
    fill_in "user_email", :with => user.email
    fill_in "user_password", :with => user.password
    # Regression test for #1257
    check "Remember me"
    click_button "Login"
  end

  it "should allow a signed in user to logout" do
    click_link "Logout"
    visit spree.root_path
    page.should have_content("Login")
    page.should_not have_content("Logout")
  end
end
