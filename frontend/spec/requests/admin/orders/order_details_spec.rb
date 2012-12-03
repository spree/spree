# coding: utf-8
require 'spec_helper'

describe "Order Details" do
  stub_authorization!

  context "edit order page" do

    before do
      reset_spree_preferences do |config|
        config.allow_backorders = true
      end
      create(:country)
    end

    after(:each) { I18n.reload! }

    let(:product) { create(:product, :name => 'spree t-shirt', :on_hand => 5, :price => 19.99) }
    let(:order) { create(:order, :completed_at => "2011-02-01 12:36:15", :number => "R100") }

    it "should allow me to edit order details", :js => true do
      order.add_variant(product.master, 2)
      order.inventory_units.each do |iu|
        iu.update_attribute_without_callbacks('state', 'sold')
      end

      visit spree.admin_path
      click_link "Orders"

      within_row(1) do
        click_link "R100"
      end

      page.should have_content("spree t-shirt")
      page.should have_content("$39.98")
      click_link "Edit"
      fill_in "order_line_items_attributes_0_quantity", :with => "1"
      click_button "Update"
      page.should have_content("Total: $19.99")
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
