require 'spec_helper'

describe "Users" do
  context "admin managing api key" do
    it "should allow an admin to clear and regenerate an api key", :js => true do
      user = Factory(:admin_user,  :email => "admin@person.com", :password => "password", :password_confirmation => "password")

      visit admin_path
      fill_in "Email", :with => user.email
      fill_in "Password", :with => user.password
      click_button "Login"
      page.should have_content("Logged in successfully")

      click_link "Users"
      within('table#listing_users tbody tr:nth-child(1)') { click_link "Edit" }
      page.should have_content("Editing User")
      click_button "Clear API key"
      page.should have_content("No key defined")
      click_button "Generate API key"
      page.should have_content("API key generated")
      click_button "Clear API key"
      page.should have_content("API key cleared")
    end
  end
end
