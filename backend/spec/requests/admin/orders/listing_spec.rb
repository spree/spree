require 'spec_helper'

describe "Orders Listing" do
  stub_authorization!

  before(:each) do
    create(:order, :created_at => Time.now + 1.day, :completed_at => Time.now + 1.day, :number => "R100")
    create(:order, :created_at => Time.now - 1.day, :completed_at => Time.now - 1.day, :number => "R200")
    visit spree.admin_path
  end

  context "listing orders" do
    before(:each) do
      click_link "Orders"
    end

    it "should list existing orders" do
      within_row(1) do
        column_text(2).should == "R100"
        column_text(3).should == "cart"
      end

      within_row(2) do
        column_text(2).should == "R200"
      end
    end

    it "should be able to sort the orders listing" do
      # default is completed_at desc
      within_row(1) { page.should have_content("R100") }
      within_row(2) { page.should have_content("R200") }

      click_link "Completed At"

      # Completed at desc
      within_row(1) { page.should have_content("R200") }
      within_row(2) { page.should have_content("R100") }

      within('table#listing_orders thead') { click_link "Number" }

      # number asc
      within_row(1) { page.should have_content("R100") }
      within_row(2) { page.should have_content("R200") }
    end
  end

  context "searching orders" do
    before(:each) do
      click_link "Orders"
    end

    it "should be able to search orders" do
      fill_in "q_number_cont", :with => "R200"
      click_icon :search
      within_row(1) do
        page.should have_content("R200")
      end

      # Ensure that the other order doesn't show up
      within("table#listing_orders") { page.should_not have_content("R100") }
    end

    it "should be able to search orders using only completed at input" do
      pending "Failing on CI server. To be investigated."
      fill_in "q_created_at_gt", :with => Date.today
      click_icon :search
      within_row(1) { page.should have_content("R100") }

      # Ensure that the other order doesn't show up
      within("table#listing_orders") { page.should_not have_content("R200") }
    end
  end
end
