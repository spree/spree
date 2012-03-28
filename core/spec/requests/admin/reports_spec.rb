require 'spec_helper'

describe "Reports" do
  context "visiting the admin reports page" do
    it "should have the right content" do
      visit spree.admin_path
      click_link "Reports"
      click_link "Sales Total"

      page.should have_content("Sales Totals")
      page.should have_content("Item Total")
      page.should have_content("Adjustment Total")
      page.should have_content("Sales Total")
    end
  end

  context "searching the admin reports page" do
    before do
      order = Factory(:order)
      order.update_attributes_without_callbacks({:adjustment_total => 100})
      order.completed_at = Time.now
      order.save!

      order = Factory(:order)
      order.update_attributes_without_callbacks({:adjustment_total => 200})
      order.completed_at = Time.now
      order.save!

      #incomplete order
      order = Factory(:order)
      order.update_attributes_without_callbacks({:adjustment_total => 50})
      order.save!

      order = Factory(:order)
      order.update_attributes_without_callbacks({:adjustment_total => 200})
      order.completed_at = 3.years.ago
      order.created_at = 3.years.ago
      order.save!

      order = Factory(:order)
      order.update_attributes_without_callbacks({:adjustment_total => 200})
      order.completed_at = 3.years.from_now
      order.created_at = 3.years.from_now
      order.save!
    end

    it "should allow me to search for reports" do
      visit spree.admin_path
      click_link "Reports"
      click_link "Sales Total"

      fill_in "search_created_at_greater_than", :with => 1.week.ago
      fill_in "search_created_at_less_than", :with => 1.week.from_now
      click_button "Search"

      page.should have_content("$300.00")
    end
  end
end
