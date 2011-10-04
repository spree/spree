require_relative '../../spec_helper'

describe Calculator::FlexiRate do
  let(:calculator) { Calculator::FlexiRate.new }
  let(:order) { mock_model Order, :line_items => [mock_model(LineItem, :amount => 10, :quantity => 4), mock_model(LineItem, :amount => 20, :quantity => 6)] }

  context "compute" do
    it "should compute amount correctly when all fees are 0" do
      calculator.compute(order).round(2).should == 0.0
    end

    it "should compute amount correctly when first_item has a value" do
      calculator.stub :preferred_first_item => 1.99
      calculator.compute(order).round(2).should == 1.99
    end
    
    it "should compute amount correctly when additional_items has a value" do
      calculator.stub :preferred_additional_item => 0.99
      expected = ( order.line_items.sum(&:quantity) - 1) * calculator.preferred_additional_item
      calculator.compute(order).round(2).should == expected.round(2)
    end
    
    it "should compute amount correctly when additional_items and first_item have values" do
      calculator.stub :preferred_first_item => 1.99, :preferred_additional_item => 0.99
      expected = (( order.line_items.sum(&:quantity) - 1) * calculator.preferred_additional_item) + calculator.preferred_first_item
      calculator.compute(order).round(2).should == expected.round(2)
    end
    
    it "should compute amount correctly when additional_items and first_item have values AND max items has value" do
      calculator.stub :preferred_first_item => 1.99, :preferred_additional_item => 0.99, :preferred_max_items => 3
      calculator.compute(order).round(2).should == 13.90
    end
    
    
  end
end
