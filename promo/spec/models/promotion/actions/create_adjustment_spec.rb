require 'spec_helper'

describe Spree::Promotion::Actions::CreateAdjustment do
  let(:order) { create(:order) }
  let(:promotion) { create(:promotion) }
  let(:action) { Spree::Promotion::Actions::CreateAdjustment.new }

  # From promotion spec:
  context "#perform" do

    before do
      action.calculator = Spree::Calculator::FreeShipping.new
      promotion.promotion_actions = [action]
      action.stub(:promotion => promotion)
    end


    it "should create a discount with correct negative amount when order is eligible" do
      order.stub(:ship_total => 2500, :item_total => 5000, :reload => nil)
      promotion.stub(:eligible? => true)

      action.perform(:order => order)
      promotion.credits_count.should == 1
      order.adjustments.count.should == 1
      order.adjustments.first.amount.to_i.should == -2500
    end

    it "should not create a discount when order already has one from this promotion" do
      order.stub(:ship_total => 5, :item_total => 50, :reload => nil)
      promotion.stub(:eligible? => true)
      action.calculator.stub(:compute => 2500)

      action.perform(:order => order)
      action.perform(:order => order)
      promotion.credits_count.should == 1
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

