require 'spec_helper'

describe "General Settings" do
  stub_authorization!

  before(:each) do
    store = create(:store, name: 'Test Store', url: 'test.example.org')
    visit spree.admin_path
    click_link "Configuration"
    click_link "General Settings"
  end

  context "visiting general settings (admin)" do
    it "should have the right content" do
      page.should have_content("General Settings")
      find("#store_name").value.should == "Test Store"
      find("#store_url").value.should == "test.example.org"
    end
  end

  context "editing general settings (admin)" do
    it "should be able to update the site name" do
      fill_in "store_name", :with => "Spree Demo Site99"
      click_button "Update"

      assert_successful_update_message(:general_settings)
      find("#store_name").value.should == "Spree Demo Site99"
    end
  end
end
