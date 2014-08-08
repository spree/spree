require 'spec_helper'

describe Spree::Promotion::Rules::ItemTotal do
  let(:rule) { Spree::Promotion::Rules::ItemTotal.new }
  let(:order) { double(:order) }

  before { rule.preferred_amount = 50 }
  before { rule.preferred_amount_max = 60 }

  context "preferred operator set to gt and preferred operator_max set to lt" do
    before do
      rule.preferred_operator = 'gt'
      rule.preferred_operator_max = 'lt'
    end

    it "should be eligible when item total is greater than preferred amount and lower than preferred amount_max" do
      order.stub :item_total => 51
      rule.should be_eligible(order)
    end

    it "should not be eligible when item total is equal to preferred amount and lower than preferred amount_max" do
      order.stub :item_total => 50
      rule.should_not be_eligible(order)
    end

    it "should not be eligible when item total is lower than preferred amount and lower than preferred amount_max" do
      order.stub :item_total => 49
      rule.should_not be_eligible(order)
    end

    it "should not be eligible when item total is greater than preferred amount and equal to preferred amount_max" do
      order.stub :item_total => 60
      rule.should_not be_eligible(order)
    end

    it "should not be eligible when item total is greater than preferred amount and greater than preferred amount_max" do
      order.stub :item_total => 61
      rule.should_not be_eligible(order)
    end

  end

  context "preferred operator set to gt and preferred operator_max set to lte" do
    before do
      rule.preferred_operator = 'gt'
      rule.preferred_operator_max = 'lte'
    end

    it "should be eligible when item total is greater than preferred amount and lower than preferred amount_max" do
      order.stub :item_total => 51
      rule.should be_eligible(order)
    end

    it "should not be eligible when item total is equal to preferred amount and lower than preferred amount_max" do
      order.stub :item_total => 50
      rule.should_not be_eligible(order)
    end

    it "should not be eligible when item total is lower than preferred amount and lower than preferred amount_max" do
      order.stub :item_total => 49
      rule.should_not be_eligible(order)
    end

    it "should be eligible when item total is greater than preferred amount and equal to preferred amount_max" do
      order.stub :item_total => 60
      rule.should be_eligible(order)
    end

    it "should not be eligible when item total is greater than preferred amount and greater than preferred amount_max" do
      order.stub :item_total => 61
      rule.should_not be_eligible(order)
    end
  end

  context "preferred operator set to gte and preferred operator_max set to lt" do
    before do
      rule.preferred_operator = 'gte'
      rule.preferred_operator_max = 'lt'
    end

    it "should be eligible when item total is greater than preferred amount and less than preferred amount_max" do
      order.stub :item_total => 51
      rule.should be_eligible(order)
    end

    it "should be eligible when item total is equal to preferred amount and lower than preferred amount_max" do
      order.stub :item_total => 50
      rule.should be_eligible(order)
    end

    it "should not be eligible when item total is lower than preferred amount and lower than preferred amount_max" do
      order.stub :item_total => 49
      rule.should_not be_eligible(order)
    end

    it "should not be eligible when item total is greater than preferred amount and equal to preferred amount_max" do
      order.stub :item_total => 60
      rule.should_not be_eligible(order)
    end

    it "should not be eligible when item total is greater than preferred amount and greater than preferred amount_max" do
      order.stub :item_total => 61
      rule.should_not be_eligible(order)
    end
  end

  context "preferred operator set to gte and preferred operator_max set to lte" do
    before do
      rule.preferred_operator = 'gte'
      rule.preferred_operator_max = 'lte'
    end

    it "should be eligible when item total is greater than preferred amount and lower than preferred amount_max" do
      order.stub :item_total => 51
      rule.should be_eligible(order)
    end

    it "should be eligible when item total is equal to preferred amount and lower than preferred amount_max" do
      order.stub :item_total => 50
      rule.should be_eligible(order)
    end

    it "should not be eligible when item total is lower than preferred amount and lower than preferred amount_max" do
      order.stub :item_total => 49
      rule.should_not be_eligible(order)
    end

    it "should be eligible when item total is greater than preferred amount and equal to preferred amount_max" do
      order.stub :item_total => 60
      rule.should be_eligible(order)
    end

    it "should not be eligible when item total is greater than preferred amount and greater than preferred amount_max" do
      order.stub :item_total => 61
      rule.should_not be_eligible(order)
    end
  end
end
