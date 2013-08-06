require 'spec_helper'

describe Spree::Promotion::Actions::CreateLineItems do
  let(:order) { create(:order) }
  let(:action) { Spree::Promotion::Actions::CreateLineItems.create }
  let(:promotion) { stub_model(Spree::Promotion) }
  let(:shirt) { create(:variant) }
  let(:mug) { create(:variant) }

  context "#perform" do
    before do
      action.stub :promotion => promotion
      action.promotion_action_line_items.create!(
        :variant => mug,
        :quantity => 1
      )
      action.promotion_action_line_items.create!(
        :variant => shirt,
        :quantity => 2
      )
    end

    context "order is eligible" do
      before do
        promotion.stub :eligible => true
      end

      it "adds line items to order with correct variant and quantity" do
        action.perform(:order => order)
        order.line_items.count.should == 2
        line_item = order.line_items.find_by_variant_id(mug.id)
        line_item.should_not be_nil
        line_item.quantity.should == 1
      end

      it "only adds the delta of quantity to an order" do
        order.contents.add(shirt, 1)
        action.perform(:order => order)
        line_item = order.line_items.find_by_variant_id(shirt.id)
        line_item.should_not be_nil
        line_item.quantity.should == 2
      end

      it "doesn't add if the quantity is greater" do
        order.contents.add(shirt, 3)
        action.perform(:order => order)
        line_item = order.line_items.find_by_variant_id(shirt.id)
        line_item.should_not be_nil
        line_item.quantity.should == 3
      end
    end
  end
end
