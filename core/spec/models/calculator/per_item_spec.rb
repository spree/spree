require 'spec_helper'

describe Spree::Calculator::PerItem do
  # Like an order object, but not quite...
  let!(:product) { double("Product") }
  let!(:line_items) { [double("LineItem", :quantity => 5, :product => product)] * 3 }
  let!(:object) { double("Order", :line_items => line_items) }
  let!(:calculable) { double("Calculable", :promotion => promotion) }
  let!(:promotion) { double("Promotion", :rules => [double("Rule", :products => [product])]) }

  let!(:calculator) do
    calculator = Spree::Calculator::PerItem.new(:preferred_amount => 10)
    calculator.stub(:calculable => calculable)
    calculator
  end

  # regression test for #1414
  it "correctly calculates per item shipping" do
    calculator.compute(object).to_f.should == 150 # 5 x 3 x 10
  end

  it "returns 0 when no object passed" do
    calculator.compute.should == 0
  end

end
