# coding: utf-8
require 'spec_helper'

describe "Order Details" do
  stub_authorization!

  context "edit order page", :js => true do
    after(:each) { I18n.reload! }

    let(:product) { create(:product, :name => 'spree t-shirt', :price => 20.00) }
    let(:order) { create(:order, :state => 'complete', :completed_at => "2011-02-01 12:36:15", :number => "R100") }
    let(:stock_location) { create(:stock_location_with_items) }
    let(:shipment) { create(:shipment, :order => order, :stock_location => stock_location) }

    before do
      configure_spree_preferences do |config|
        config.allow_backorders = true
      end
      create(:country)
      create(:shipping_method, :name => "Default")
      create(:product, :name => "Tote", :price => 15.00)
      order.shipments.create({stock_location_id: stock_location.id}, :without_protection => true)
      order.contents.add(product.master, 2)
    end

    it "should allow me to edit order details" do
      visit spree.edit_admin_order_path(order)
      page.should have_content("spree t-shirt")
      page.should have_content("$40.00")

      within_row(1) do
        click_icon :edit
        fill_in "quantity", :with => "1"
      end
      click_icon :ok
      sleep 1
      page.should have_content("Total: $20.00")
    end

    it "can add an item to a shipment" do
      visit spree.edit_admin_order_path(order)

      select2_search "Tote", :from => I18n.t(:name_or_sku)
      within("table.stock-levels") do
        fill_in "stock_item_quantity", :with => 2
        click_icon :plus
      end
      sleep 1
      page.should have_content("Total: $40.00")
    end

    it "can remove an item from a shipment" do
      visit spree.edit_admin_order_path(order)
      page.should have_content("spree t-shirt")

      within_row(1) do
        click_icon :trash
      end
      sleep 1
      page.should_not have_content("spree t-shirt")
    end

    it "can add tracking information" do
      visit spree.edit_admin_order_path(order)
      within("table.index tr:nth-child(5)") do
        click_icon :edit
      end
      fill_in "tracking", :with => "FOOBAR"
      click_icon :ok
      sleep 1
      page.should have_content("Tracking: FOOBAR")
    end

    it "can add change the shipping method" do
      order = create(:completed_order_with_totals)
      visit spree.edit_admin_order_path(order)
      within("table.index tr.show-method") do
        click_icon :edit
      end
      select2 "Default", :from => "Shipping Method"
      click_icon :ok
      sleep 1
      page.should have_content("Default:")
    end
  end
end
