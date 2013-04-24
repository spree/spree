require 'spec_helper'

describe "Mail Methods" do
  stub_authorization!

  before(:each) do
    visit spree.admin_path
    click_link "Configuration"
  end

  context "edit" do
    before(:each) do
      click_link "Mail Method Settings"
    end

    it "should be able to edit mail method settings" do
      fill_in "mail_bcc", :with => "spree@example.com99"
      click_button "Update"
      page.should have_content("successfully updated!")
    end

    # Regression test for #2094
    it "does not clear password if not provided" do
      Spree::Config[:smtp_password] = "haxme"
      click_button "Update"
      page.should have_content("successfully updated!")

      Spree::Config[:smtp_password].should_not be_blank
    end
  end
end
