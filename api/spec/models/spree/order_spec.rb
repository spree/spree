require 'spec_helper'

module Spree
  describe Order do
    let(:user) { stub_model(User) }

    it 'can build an order from API parameters' do

      Spree::Variant.should_receive(:find).and_return(stub_model(Variant, :id => 1))
      order = Order.build_from_api(user, { :line_items => [{ :variant_id => 1, :quantity => 5 }]})

      order.user.should == user
      line_item = order.line_items.first
      line_item.quantity.should == 5
      line_item.variant_id.should == 1
    end
  end
end
