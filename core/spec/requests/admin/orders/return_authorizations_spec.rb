require 'spec_helper'

describe "return authorizations" do
  let!(:order) { Factory(:completed_order_with_totals) }

  before do
    order.inventory_units.update_all("state = 'shipped'")
    Factory(:return_authorization,
            :order => order,
            :state => 'authorized',
            :inventory_units => order.inventory_units)
  end

  # Regression test for #1107
  it "doesn't blow up when receiving a return authorization" do
    visit spree.admin_path
    click_link "Orders"
    click_link order.number
    click_link "Return Authorizations"
    click_link "Edit"
    lambda { click_button "receive" }.should_not raise_error(ActiveRecord::UnknownAttributeError)
  end

end
