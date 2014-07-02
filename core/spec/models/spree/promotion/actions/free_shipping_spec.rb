require 'spec_helper'

describe Spree::Promotion::Actions::FreeShipping do
  let(:order) { Spree::Order.new }
  let(:promotion) { build(:promotion) }
  let(:action) { Spree::Promotion::Actions::FreeShipping.new(promotion: promotion) }

  # From promotion spec:
  context "#perform" do
    before do
      order.shipments << Spree::Shipment.new(cost: 10)
      promotion.promotion_actions << action
    end

    it "should create a discount with correct negative amount" do
      order.shipments.to_a.count.should == 1
      action.perform(:order => order).should be_true
      order.shipment_adjustments.count.should == 1
      order.shipment_adjustments.first.amount.to_i.should == -10
    end

    it "should not create a discount when order already has one from this promotion" do
      action.perform(:order => order).should be_true
      action.perform(:order => order).should be_false
      order.shipment_adjustments.count.should == 1
    end
  end
end