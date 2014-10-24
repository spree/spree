require 'spec_helper'

describe "Analytics Tracker", :type => :feature do
  stub_authorization!

  context "index" do
    before(:each) do
      2.times { create(:tracker, :environment => "test") }
      visit spree.admin_path
      click_link "Configuration"
      click_link "Analytics Tracker"
    end

    it "should have the right content" do
      expect(page).to have_content("Analytics Trackers")
    end

    it "should have the right tabular values displayed" do
      within_row(1) do
        expect(column_text(1)).to eq("A100")
        expect(column_text(2)).to eq("Test")
        expect(column_text(3)).to eq("Yes")
      end

      within_row(2) do
        expect(column_text(1)).to eq("A100")
        expect(column_text(2)).to eq("Test")
        expect(column_text(3)).to eq("Yes")
      end
    end
   end

  context "create", js: true do
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

      expect(page).to have_content("successfully created!")
      within_row(1) do
        expect(column_text(1)).to eq("A100")
        expect(column_text(2)).to eq("Test")
        expect(column_text(3)).to eq("Yes")
      end
    end
  end
end
