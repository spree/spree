require 'spec_helper'

describe "Shipments", :type => :feature do
  stub_authorization!

  let!(:order) { create(:order_ready_to_ship, :number => "R100", :state => "complete") }

  # Regression test for #4025
  context "a shipment without a shipping method" do
    before do
      order.shipments.each do |s|
        # Deleting the shipping rates causes there to be no shipping methods
        s.shipping_rates.delete_all
      end
    end

    it "can still be displayed" do
      expect { visit spree.edit_admin_order_path(order) }.not_to raise_error
    end
  end

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
      wait_for_ajax

      expect(page).to have_content("SHIPPED PACKAGE")
      expect(order.reload.shipment_state).to eq("shipped")
    end
  end
end
