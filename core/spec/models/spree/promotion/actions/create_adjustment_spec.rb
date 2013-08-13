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

    it "should create a discount with correct negative amount" do
      action.perform(:order => order)
      promotion.credits_count.should == 1
      order.adjustments.count.should == 1
      order.adjustments.first.amount.to_i.should == -10
    end

    it "should not create a discount when order already has one from this promotion" do
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

  context "#compute_amount" do
    before do
      action.calculator = Spree::Calculator::FreeShipping.new
    end

    it "should always return a negative amount" do
      order.stub(:item_total => 1000)
      action.calculator.stub(:compute => -200)
      action.compute_amount(order).to_i.should == -200
      action.calculator.stub(:compute => 300)
      action.compute_amount(order).to_i.should == -300
    end
    it "should not return an amount that exceeds order's item_total + ship_total" do
      order.stub(:item_total => 1000, :ship_total => 100)
      action.calculator.stub(:compute => 1000)
      action.compute_amount(order).to_i.should == -1000
      action.calculator.stub(:compute => 1100)
      action.compute_amount(order).to_i.should == -1100
      action.calculator.stub(:compute => 1200)
      action.compute_amount(order).to_i.should == -1100
    end
  end

end

