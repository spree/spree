require 'spec_helper'

describe "Shipping Methods" do
  stub_authorization!
  let!(:zone) { create(:global_zone) }
  let!(:shipping_method) { create(:shipping_method, :zone => zone) }

  before(:each) do
    # HACK: To work around no email prompting on check out
    Spree::Order.any_instance.stub(:require_email => false)
    create(:payment_method, :environment => 'test')

    visit spree.admin_path
    click_link "Configuration"
  end


  context "show" do
    it "should display exisiting shipping methods" do
      click_link "Shipping Methods"

      within_row(1) do
        column_text(1).should == shipping_method.name 
        column_text(2).should == zone.name
        column_text(3).should == "Flat Rate (per order)"
        column_text(4).should == "Both"
      end
    end
  end

  context "create" do
    it "should be able to create a new shipping method" do
      click_link "Shipping Methods"
      click_link "admin_new_shipping_method_link"
      page.should have_content("New Shipping Method")
      fill_in "shipping_method_name", :with => "bullock cart"
      click_button "Create"
      page.should have_content("successfully created!")
      page.should have_content("Editing Shipping Method")
    end
  end

  # Regression test for #1331
  context "update" do
    it "can change the calculator", :js => true do
      click_link "Shipping Methods"
      within("#listing_shipping_methods") do
        click_icon :edit
      end

      click_button "Update"
      page.should_not have_content("Shipping method is not found")
    end
  end

  context "availability", :js => true do
    it "can check shipping method match fields" do
      click_link "Shipping Methods"
      click_link "New Shipping Method"
      ["none", "one", "all"].each do |type|
        field = "shipping_method_match_#{type}"
        check field
        uncheck field
      end
    end
  end
end
