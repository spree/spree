require 'spec_helper'

describe Spree::Calculator::FlatPercentItemTotal do
  let(:calculator) { Spree::Calculator::FlatPercentItemTotal.new }
  let(:line_item1) { mock_model(Spree::LineItem, :amount => 10) }
  let(:line_item2) { mock_model(Spree::LineItem, :amount => 20) }
  let(:order) { mock_model Spree::Order, :line_items => [line_item1, line_item2] }

  before { calculator.stub :preferred_flat_percent => 10 }

  context "compute" do
    it "should compute amount correctly" do
      calculator.compute(order).should == 3.0
    end

    it "should round result correctly" do
      order.stub :line_items => [mock_model(Spree::LineItem, :amount => 10.56), mock_model(Spree::LineItem, :amount => 20.49)]
      calculator.compute(order).should == 3.11

      order.stub :line_items => [mock_model(Spree::LineItem, :amount => 10.56), mock_model(Spree::LineItem, :amount => 20.48)]
      calculator.compute(order).should == 3.10
    end

    it "should compute amount correctly for a single line item" do
      calculator.compute(line_item1).should == 1.0
    end
  end
end
