require 'spec_helper'

describe Spree::Promotion::Actions::FreeShipping do
  let(:order) { create(:completed_order_with_totals) }
  let(:promotion) { create(:promotion) }
  let(:action) { Spree::Promotion::Actions::FreeShipping.create }
  let(:payload) { { order: order } }

  # From promotion spec:
  context "#perform" do
    before do
      order.shipments << create(:shipment)
      promotion.promotion_actions << action
    end

    it "should create a discount with correct negative amount" do
      order.shipments.count.should == 2
      order.shipments.first.cost.should == 100
      order.shipments.last.cost.should == 100
      action.perform(payload).should be true
      promotion.credits_count.should == 2
      order.shipment_adjustments.count.should == 2
      order.shipment_adjustments.first.amount.to_i.should == -100
      order.shipment_adjustments.last.amount.to_i.should == -100
    end

    it "should not create a discount when order already has one from this promotion" do
      action.perform(payload).should be true
      action.perform(payload).should be false
      promotion.credits_count.should == 2
      order.shipment_adjustments.count.should == 2
    end
  end
end
