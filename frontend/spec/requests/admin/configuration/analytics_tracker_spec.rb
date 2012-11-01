require 'spec_helper'

describe "Analytics Tracker" do
  stub_authorization!

  context "index" do
    before(:each) do
      2.times { create(:tracker, :environment => "test") }
      visit spree.admin_path
      click_link "Configuration"
      click_link "Analytics Tracker"
    end

    it "should have the right content" do
      page.should have_content("Analytics Trackers")
    end

    it "should have the right tabular values displayed" do
      within_row(1) do
        column_text(1).should == "A100"
        column_text(2).should == "Test"
        column_text(3).should == "Yes"
      end

      within_row(2) do
        column_text(1).should == "A100"
        column_text(2).should == "Test"
        column_text(3).should == "Yes"
      end
    end
   end

  context "create" do
    before(:each) do
      visit spree.admin_path
      click_link "Configuration"
      click_link "Analytics Tracker"
    end

    it "should be able to create a new analytics tracker" do
      click_link "admin_new_tracker_link"
      fill_in "tracker_analytics_id", :with => "A100"
      select "Test", :from => "tracker-env"
      click_button "Create"

      page.should have_content("successfully created!")
      within_row(1) do
        column_text(1).should == "A100"
        column_text(2).should == "Test"
        column_text(3).should == "Yes"
      end
    end
  end
end
