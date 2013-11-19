require 'spec_helper'

describe Spree::Promotion::Actions::CreateAdjustment do
  let(:order) { create(:order_with_line_items, :line_items_count => 1) }
  let(:promotion) { create(:promotion) }
  let(:action) { Spree::Promotion::Actions::CreateAdjustment.new }

  # From promotion spec:
  context "#perform" do
    before do
      action.calculator = Spree::Calculator::FlatRate.new(:preferred_amount => 10)
      promotion.promotion_actions = [action]
      action.stub(:promotion => promotion)
    end

    # Regression test for #3966
    it "does not apply an adjustment if the amount is 0" do
      action.calculator.preferred_amount = 0
      action.perform(:order => order)
      promotion.credits_count.should == 0
      order.adjustments.count.should == 0
    end

    it "should create a discount with correct negative amount" do
      order.shipments.create!(:cost => 10)

      action.perform(:order => order)
      promotion.credits_count.should == 1
      order.adjustments.count.should == 1
      order.adjustments.first.amount.to_i.should == -10
    end

    it "should create a discount accessible through both order_id and adjustable_id" do
      action.perform(:order => order)
      order.adjustments.count.should == 1
      order.all_adjustments.count.should == 1
    end

    it "should not create a discount when order already has one from this promotion" do
      order.shipments.create!(:cost => 10)

      action.perform(:order => order)
      action.perform(:order => order)
      promotion.credits_count.should == 1
    end
  end

  context "#destroy" do
    before(:each) do
      action.calculator = Spree::Calculator::FlatRate.new(:preferred_amount => 10)
      promotion.promotion_actions = [action]
    end

    context "when order is not complete" do
      it "should not keep the adjustment" do
        action.perform(:order => order)
        action.destroy
        order.adjustments.count.should == 0
      end
    end

    context "when order is complete" do
      let(:order) do
        create(:order_with_line_items,
               :state => "complete",
               :completed_at => Time.now,
               :line_items_count => 1)
      end

      before(:each) do
        action.perform(:order => order)
        action.destroy
      end

      it "should keep the adjustment" do
        order.adjustments.count.should == 1
      end

      it "should nullify the adjustment source" do
        order.adjustments.reload.first.source.should be_nil
      end
    end
  end
end
