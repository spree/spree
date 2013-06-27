require 'spec_helper'

describe Spree::Promotion::Actions::CreateLineItems do
  let(:order) { create(:order) }
  let(:action) { Spree::Promotion::Actions::CreateLineItems.create }

  context "#perform" do
    context "order is not eligible" do
      before { action.stub(eligible?: false) }

      it "doesn't create line items" do
        expect(order.line_items.count).to eql 0

        action.perform(:order => order)
        expect(order.line_items.count).to eql 0
      end
    end

    context "order is eligible" do
      let(:mug) { create(:variant) }
      let(:shirt) { create(:variant) }

      before do
        action.stub(eligible?: true)

        action.promotion_action_line_items.create!({
          :variant => mug,
          :quantity => 1}, :without_protection => true
        )
        action.promotion_action_line_items.create!({
          :variant => shirt,
          :quantity => 2}, :without_protection => true
        )
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
