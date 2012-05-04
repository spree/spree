require 'spec_helper'

describe "Analytics Tracker" do
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
      find('table.index tr:nth-child(1) td:nth-child(1)').text.should == "A100"
      find('table.index tr:nth-child(1) td:nth-child(2)').text.should == "Test"
      find('table.index tr:nth-child(1) td:nth-child(3)').text.should == "Yes"

      find('table.index tr:nth-child(2) td:nth-child(1)').text.should == "A100"
      find('table.index tr:nth-child(2) td:nth-child(2)').text.should == "Test"
      find('table.index tr:nth-child(2) td:nth-child(3)').text.should == "Yes"
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
      find('table.index tr:nth-child(1) td:nth-child(1)').text.should == "A100"
      find('table.index tr:nth-child(1) td:nth-child(2)').text.should == "Test"
      find('table.index tr:nth-child(1) td:nth-child(3)').text.should == "Yes"
    end
  end
end
