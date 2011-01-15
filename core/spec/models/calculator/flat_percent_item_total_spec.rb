require File.dirname(__FILE__) + '/../../spec_helper'

describe Calculator::FlatPercentItemTotal do
  let(:calculator) { Calculator::FlatPercentItemTotal.new }
  let(:order) { mock_model Order, :line_items => [mock_model(LineItem, :amount => 10), mock_model(LineItem, :amount => 20)] }

  before { calculator.stub :preferred_flat_percent => 10 }

  context "compute" do
    it "should compute amount correctly" do
      calculator.compute(order).should == 3.0
    end

    it "should round result correctly" do
      order.stub :line_items => [mock_model(LineItem, :amount => 10.56), mock_model(LineItem, :amount => 20.49)]
      calculator.compute(order).should == 3.11

      order.stub :line_items => [mock_model(LineItem, :amount => 10.56), mock_model(LineItem, :amount => 20.48)]
      calculator.compute(order).should == 3.10
    end
  end
end
