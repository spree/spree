require 'spec_helper'

describe "Shipments" do
  stub_authorization!

  let!(:order) { create(:order_ready_to_ship, :number => "R100", :state => "complete") }

  context "shipping an order", js: true do
    before(:each) do
      visit spree.admin_path
      click_link "Orders"
      within_row(1) do
        click_link "R100"
      end
    end

    it "can ship a completed order" do
      click_link "ship"
      sleep 1

      page.should have_content("shipped package")
      order.reload.shipment_state.should == "shipped"
    end
  end

  context "moving variants between shipments", js: true do
    let!(:la) { create(:stock_location, name: "LA") }
    before(:each) do
      create(:stock_location, name: "LA")
      visit spree.admin_path
      click_link "Orders"
      within_row(1) do
        click_link "R100"
      end
    end

    it "can move a variant to a new and to an existing shipment" do
      order.shipments.count.should == 1

      within_row(1) { click_icon 'resize-horizontal' }
      targetted_select2 'LA', from: '#s2id_item_stock_location'
      click_icon :ok
      page.find("table.stock-contents:eq(2)").should be_visible

      within_row(1) { click_icon 'resize-horizontal' }
      targetted_select2 "LA(#{order.reload.shipments.last.number})", from: '#s2id_item_stock_location'
      click_icon :ok
      page.find("table.stock-contents:eq(2)").should be_visible
    end
  end
end
