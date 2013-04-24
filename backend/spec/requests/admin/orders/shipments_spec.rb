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
end
