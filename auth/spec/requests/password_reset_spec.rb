require 'spec_helper'

describe "Reset Password" do
  it "should allow the user to indicate they have forgotten their password" do
    visit spree.login_path
    click_link "Forgot Password?"
    page.should have_content("your password will be emailed to you")
  end

  it "should allow a user to supply an email for the password reset" do
    user = create(:user, :email => "foobar@example.com", :password => "secret", :password_confirmation => "secret")
    visit spree.login_path
    click_link "Forgot Password?"
    fill_in "user_email", :with => "foobar@example.com"
    click_button "Reset my password"
    page.should have_content("You will receive an email with instructions")
  end
end
