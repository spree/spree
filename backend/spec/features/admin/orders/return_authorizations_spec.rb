require 'spec_helper'

describe "return authorizations", :type => :feature do
  stub_authorization!

  let!(:order) { create(:shipped_order) }

  before do
    create(:return_authorization,
            :order => order,
            :state => 'authorized',
            :inventory_units => order.shipments.first.inventory_units,
            :stock_location_id => order.shipments.first.stock_location_id)
  end

  # Regression test for #1107
  it "doesn't blow up when receiving a return authorization" do
    visit spree.admin_path
    click_link "Orders"
    click_link order.number
    click_link "Return Authorizations"
    click_link "Edit"
    expect { click_button "receive" }.not_to raise_error
  end

end
