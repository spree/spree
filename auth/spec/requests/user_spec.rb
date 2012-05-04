require 'spec_helper'

describe "Users" do
  before(:each) do
    user = create(:admin_user, :email => "admin@person.com", :password => "password", :password_confirmation => "password")
    visit spree.admin_path
    fill_in "user_email", :with => user.email
    fill_in "user_password", :with => user.password
    click_button "Login"
    click_link "Users"
    within('table#listing_users td.user_email') { click_link "admin@person.com" }
    click_link "Edit"
    page.should have_content("Editing User")
  end

  it "admin editing email with validation error" do
    fill_in "user_email", :with => "a"
    click_button "Update"
    page.should have_content("Email is invalid")
  end

  it "admin editing roles" do
    check "user_role_user"
    click_button "Update"
    page.should have_content("User has been successfully updated!")
    within('table#listing_users') { click_link "Edit" }
    find_field('user_role_user')['checked'].should be_true
  end

  it "listing users when anonymous users are present" do
    Spree::User.anonymous!
    click_link "Users"
    page.should_not have_content("@example.net")
  end
end
