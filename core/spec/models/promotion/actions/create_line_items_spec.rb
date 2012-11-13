require 'spec_helper'

describe Spree::Promotion::Actions::CreateLineItems do
  let(:order) { create(:order) }
  let(:promotion) { Spree::Promotion.new }
  let(:action) { Spree::Promotion::Actions::CreateLineItems.create }

  context "#perform" do
    before do
      @v1 = create(:variant)
      @v2 = create(:variant)
      action.promotion_action_line_items.create!({
        :variant => @v1,
        :quantity => 1}, :without_protection => true
      )
      action.promotion_action_line_items.create!({
        :variant => @v2,
        :quantity => 2}, :without_protection => true
      )
    end

    it "adds line items to order with correct variant and quantity" do
      action.perform(:order => order)
      order.line_items.count.should == 2
      line_item = order.line_items.find_by_variant_id(@v1.id)
      line_item.should_not be_nil
      line_item.quantity.should == 1
    end

    it "only adds the delta of quantity to an order" do
      order.add_variant(@v2, 1)
      action.perform(:order => order)
      line_item = order.line_items.find_by_variant_id(@v2.id)
      line_item.should_not be_nil
      line_item.quantity.should == 2
    end

    it "doesn't add if the quantity is greater" do
      order.add_variant(@v2, 3)
      action.perform(:order => order)
      line_item = order.line_items.find_by_variant_id(@v2.id)
      line_item.should_not be_nil
      line_item.quantity.should == 3
    end
  end
end

