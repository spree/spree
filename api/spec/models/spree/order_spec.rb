require 'spec_helper'

module Spree
  describe Order do
    let(:user) { stub_model(LegacyUser) }

    it 'can build an order from API parameters' do
      product = Spree::Product.create!(:name => 'Test', :sku => 'TEST-1', :price => 33.22)
      variant_id = product.master.id
      order = Order.build_from_api(user, { :line_items_attributes => [{ :variant_id => variant_id, :quantity => 5 }]})

      order.user.should == user
      line_item = order.line_items.first
      line_item.quantity.should == 5
      line_item.variant_id.should == variant_id
    end
  end
end
