require 'spec_helper'

describe "Mail Methods" do
  stub_authorization!

  before(:each) do
    visit spree.admin_path
    click_link "Configuration"
  end

  context "index" do
    before(:each) do
      create(:mail_method)
      click_link "Mail Methods"
    end

    it "should be able to display information about existing mail methods" do
      within_row(1) do
        column_text(1).should == "Test"
        column_text(2).should == "Yes"
      end
    end
  end

  context "create" do
    it "should be able to create a new mail method" do
      click_link "Mail Methods"
      click_link "admin_new_mail_method_link"
      page.should have_content("New Mail Method")
      click_button "Create"
      page.should have_content("successfully created!")
    end
  end

  context "edit" do
    before(:each) do
      create(:mail_method)
      click_link "Mail Methods"
    end

    it "should be able to edit an existing mail method" do
      within_row(1) { click_icon :edit }

      fill_in "mail_method_preferred_mail_bcc", :with => "spree@example.com99"
      click_button "Update"
      page.should have_content("successfully updated!")

      within_row(1) { click_icon :edit }
      find_field("mail_method_preferred_mail_bcc").value.should == "spree@example.com99"
    end
  end
end
