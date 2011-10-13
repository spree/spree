require 'spec_helper'

describe Spree::Promotion::Rules::ItemTotal do
  let(:rule) { Spree::Promotion::Rules::ItemTotal.new }
  let(:order) { mock_model(Spree::Order, :user => nil) }
  # let(:order) { mock_model Order, :line_items => [mock_model(LineItem, :amount => 10), mock_model(LineItem, :amount => 20)] }

  before { rule.preferred_amount = 50 }

  context "preferred operator set to gt" do
    before { rule.preferred_operator = 'gt' }

    it "should be eligible when item total is greater than preferred amount" do
      # order.stub(:item_total => 51)
      order.stub :line_items => [mock_model(Spree::LineItem, :amount => 30), mock_model(Spree::LineItem, :amount => 21)]
      rule.should be_eligible(order)
    end

    it "should not be eligible when item total is equal to preferred amount" do
      # order.stub(:item_total => 50)
      order.stub :line_items => [mock_model(Spree::LineItem, :amount => 30), mock_model(Spree::LineItem, :amount => 20)]
      rule.should_not be_eligible(order)
    end

    it "should not be eligible when item total is lower than to preferred amount" do
      order.stub :line_items => [mock_model(Spree::LineItem, :amount => 30), mock_model(Spree::LineItem, :amount => 19)]
      rule.should_not be_eligible(order)
    end
  end

  context "preferred operator set to gte" do
    before { rule.preferred_operator = 'gte' }

    it "should be eligible when item total is greater than preferred amount" do
      order.stub :line_items => [mock_model(Spree::LineItem, :amount => 30), mock_model(Spree::LineItem, :amount => 21)]
      rule.should be_eligible(order)
    end

    it "should be eligible when item total is equal to preferred amount" do
      order.stub :line_items => [mock_model(Spree::LineItem, :amount => 30), mock_model(Spree::LineItem, :amount => 20)]
      rule.should be_eligible(order)
    end

    it "should not be eligible when item total is lower than to preferred amount" do
      order.stub :line_items => [mock_model(Spree::LineItem, :amount => 30), mock_model(Spree::LineItem, :amount => 19)]
      rule.should_not be_eligible(order)
    end
  end
end
