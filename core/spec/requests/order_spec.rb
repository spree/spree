require 'spec_helper'

describe 'orders' do
  let(:order) { create(:order, :shipping_method => create(:shipping_method)) }

  it "can visit an order" do
    # Regression test for current_user call on orders/show
    lambda { visit spree.order_path(order) }.should_not raise_error
  end
end
