# coding: utf-8
require 'spec_helper'

describe "Order Details" do
  stub_authorization!

  context "edit order page" do

    before do
      create(:country)
      create(:stock_location_with_items)
    end

    after(:each) { I18n.reload! }

    let(:product) { create(:product, :name => 'spree t-shirt', :price => 20.00) }
    let(:order) { create(:order, :state => 'complete', :completed_at => "2011-02-01 12:36:15", :number => "R100") }
    let(:shipment) { create(:shipment, :order => order) }

    it "should allow me to edit order details", :js => true do
      shipment.add(product.master, 2)
      visit spree.admin_path
      click_link "Orders"

      within_row(1) do
        click_link "R100"
      end

      page.should have_content("spree t-shirt")
      page.should have_content("$40.00")

      within("table.stock-contents") do
        click_icon :edit
        fill_in "quantity", :with => "1"
      end
      click_icon :ok
      sleep 1
      page.should have_content("Total: $20.00")
    end

    it "should render details properly" do
      order.state = :complete
      order.currency = 'GBP'
      order.save!

      visit spree.edit_admin_order_path(order)

      find(".page-title").text.strip.should == "Order #R100"

      within ".additional-info" do
        find(".state").text.should == "complete"
        find("#shipment_status").text.should == "none"
        find("#payment_status").text.should == "none"
      end

      I18n.backend.store_translations I18n.locale,
        :shipment_states => { :missing => 'some text' },
        :payment_states  => { :missing => 'other text' }

      visit spree.edit_admin_order_path(order)

      within ".additional-info" do
        find("#order_total").text.should == "£0.00"
        find("#shipment_status").text.should == "some text"
        find("#payment_status").text.should == "other text"
      end

    end
  end
end
