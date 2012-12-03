require 'spec_helper'

describe "Adjustments" do
  stub_authorization!

  before(:each) do
    visit spree.admin_path
    order = create(:order, :completed_at => "2011-02-01 12:36:15", :number => "R100")
    create(:adjustment, :adjustable => order)
    click_link "Orders"
    within_row(1) { click_icon :edit }
    click_link "Adjustments"
  end

  context "admin managing adjustments" do
    it "should display the correct values for existing order adjustments" do
      within_row(1) do
        column_text(2).should == "Shipping"
        column_text(3).should == "$100.00"
      end
    end
  end

  context "admin creating a new adjustment" do
    before(:each) do
      click_link "New Adjustment"
    end

    context "successfully" do
      it "should create a new adjustment" do
        fill_in "adjustment_amount", :with => "10"
        fill_in "adjustment_label", :with => "rebate"
        click_button "Continue"
        page.should have_content("successfully created!")
      end
    end

    context "with validation errors" do
      it "should not create a new adjustment" do
        fill_in "adjustment_amount", :with => ""
        fill_in "adjustment_label", :with => ""
        click_button "Continue"
        page.should have_content("Label can't be blank")
        page.should have_content("Amount is not a number")
      end
    end
  end

  context "admin editing an adjustment" do
    before(:each) do
      within_row(1) { click_icon :edit }
    end

    context "successfully" do
      it "should update the adjustment" do
        fill_in "adjustment_amount", :with => "99"
        fill_in "adjustment_label", :with => "rebate 99"
        click_button "Continue"
        page.should have_content("successfully updated!")
        page.should have_content("rebate 99")
        page.should have_content("$99.00")
      end
    end

    context "with validation errors" do
      it "should not update the adjustment" do
        fill_in "adjustment_amount", :with => ""
        fill_in "adjustment_label", :with => ""
        click_button "Continue"
        page.should have_content("Label can't be blank")
        page.should have_content("Amount is not a number")
      end
    end
  end
end
