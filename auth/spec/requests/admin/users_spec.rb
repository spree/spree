require 'spec_helper'

describe 'Users' do
  before do
    create(:user, :email => "a@example.com")
    user = create(:admin_user, :email => "c@example.com")
    sign_in_as!(user)
    visit spree.admin_users_path
  end

  context "listing users" do
    it "should list users" do
      page.should have_content("a@example.com")
    end

    it "should not list anonymous users" do
      Spree::User.anonymous!
      click_link "Users"
      page.should_not have_content("@example.net")
    end
  end

  context "creating users" do
    it "should let me create a new user" do
      click_link "New User"
      fill_in "user_email", :with => "new@example.com"
      fill_in "user_password", :with => "password"
      fill_in "user_password_confirmation", :with => "password"
      check "user_role_user"
      click_button "Create"

      page.should have_content("successfully created!")
      page.should have_content("new@example.com")

      click_link "new@example.com"
      click_link "Edit"
      find_field('user_role_user')['checked'].should be_true
    end
  end

  context "editing users" do
    before(:each) do
      click_link("a@example.com")
      click_link("Edit")
    end

    it "should let me edit the user email" do
      fill_in "user_email", :with => "a@example.com99"
      click_button "Update"

      page.should have_content("successfully updated!")
      page.should have_content("a@example.com99")
    end

    it "should let me edit the user password" do
      fill_in "user_password", :with => "welcome"
      fill_in "user_password_confirmation", :with => "welcome"
      click_button "Update"

      page.should have_content("successfully updated!")
    end

    it "should not let me use an invalid email" do
      fill_in "user_email", :with => "a"
      click_button "Update"
      page.should have_content("Email is invalid")
    end

    it "should let me edit the user's roles" do
      check "user_role_user"
      click_button "Update"
      page.should have_content("User has been successfully updated!")
      within('table#listing_users') { click_link "Edit" }
      find_field('user_role_user')['checked'].should be_true
    end
  end

  context "editing own user" do
    it "should let me edit own password" do
      click_link("c@example.com")
      click_link("Edit")
      fill_in "user_password", :with => "welcome"
      fill_in "user_password_confirmation", :with => "welcome"
      click_button "Update"

      page.should have_content("successfully updated!")
    end
  end
end
