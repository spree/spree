require 'spec_helper'

describe 'orders' do
  let(:order) { create(:order, :shipping_method => create(:shipping_method)) }
  let(:completed_order) { create(:completed_order_with_totals, :shipping_method => create(:shipping_method)) }

  it "can visit an order" do
    # Regression test for current_user call on orders/show
    lambda { visit spree.order_path(order) }.should_not raise_error
  end

  it "should have credit card info if paid with credit card" do
    create(:payment, :order => completed_order)
    visit spree.order_path(completed_order)
    page.should have_content "Ending in 1111"
  end

  it "should have payment method name visible if not paid with credit card" do
    create(:check_payment, :order => completed_order)
    visit spree.order_path(completed_order)
    page.should have_content "Check"
  end
end
