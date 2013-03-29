require 'spec_helper'

describe Spree::Calculator::PerItem do
  # Like an order object, but not quite...
  let!(:product1) { double("Product") }
  let!(:product2) { double("Product") }
  let!(:line_items) { [double("LineItem", :quantity => 5, :product => product1), double("LineItem", :quantity => 3, :product => product2)] }
  let!(:object) { double("Order", :line_items => line_items) }

  let!(:shipping_calculable) { double("Calculable") }
  let!(:promotion_calculable) { double("Calculable", :promotion => promotion) }

  let!(:promotion) { double("Promotion", :rules => [double("Rule", :products => [product1])]) }
  let!(:promotion_without_rules) { double("Promotion", :rules => []) }

  let!(:calculator) { Spree::Calculator::PerItem.new(:preferred_amount => 10) }

  # regression test for #1414
  it "correctly calculates per item shipping" do
    calculator.stub(:calculable => shipping_calculable)
    calculator.compute(object).to_f.should == 80 # 5 x 10 + 3 x 10
  end

  it "correctly calculates per item promotion" do
    calculator.stub(:calculable => promotion_calculable)
    calculator.compute(object).to_f.should == 50 # 5 x 10
  end

  it 'correctly calculates per item promotion with no rules i.e. no product restrictions' do
    calculator.stub(:calculable => double("Calculable", :promotion => promotion_without_rules))
    calculator.compute(object).to_f.should == 80 # 5 x 10 + 3 x 10
  end

  it "returns 0 when no object passed" do
    calculator.stub(:calculable => shipping_calculable)
    calculator.compute.should == 0
  end

  it "returns 0 when no object passed" do
    calculator.stub(:calculable => promotion_calculable)
    calculator.compute.should == 0
  end

  # Regression test for #2322
  context "does not fail if a promotion rule does not respond to products" do
    before { promotion.stub :rules => [double("Rule")] }
    specify do
      calculator.stub(:calculable => promotion_calculable)
      expect { calculator.matching_products }.not_to raise_error
    end
  end
end
