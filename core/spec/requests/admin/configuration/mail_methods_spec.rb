require 'spec_helper'

describe "Mail Methods" do
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
      find("table.index tbody tr td:nth-child(1)").text.should == "Test"
      find("table.index tbody tr td:nth-child(2)").text.should == "Yes"
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
      within(:css, "table.index tbody tr") { click_link "Edit" }
      fill_in "mail_method_preferred_mail_bcc", :with => "spree@example.com99"
      click_button "Update"
      page.should have_content("successfully updated!")
      within(:css, "table.index tbody tr") { click_link "Edit" }
      find_field("mail_method_preferred_mail_bcc").value.should == "spree@example.com99"
    end
  end
end
