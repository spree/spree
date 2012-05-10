require 'spec_helper'

describe Spree::Calculator::PerItem do
  # Like an order object, but not quite...
  let!(:line_items) { [double("LineItem", :quantity => 5, :product => :a_product )] * 3 }
  let!(:object) { double("Order", :line_items => line_items) }
  let!(:mock_product_set) { double("Array") }
  let!(:calculator) { Spree::Calculator::PerItem.new(:preferred_amount => 10) } 

  # regression test for #1414
  it "correctly calculates per item shipping" do
    mock_product_set.stub(:include?).with(any_args()).and_return(true)
    calculator.stub(:target_products).and_return(mock_product_set)
    calculator.compute(object).to_f.should == 150 # 5 x 3 x 10
  end

  it "returns 0 when no object passed" do
    calculator.stub(:target_products).and_return(mock_product_set)
    calculator.compute.should == 0
  end

end
