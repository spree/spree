require 'spec_helper'

describe 'Users' do
  before do
    user = create(:admin_user, :email => "c@example.com")
    sign_in_as!(user)
    visit spree.admin_users_path
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
