require 'spec_helper'

describe Spree::Calculator::PercentPerItem do
  # Like an order object, but not quite...
  let!(:product1) { double("Product") }
  let!(:product2) { double("Product") }
  let!(:line_items) { [double("LineItem", :quantity => 5, :product => product1, :price => 10), double("LineItem", :quantity => 1, :product => product2, :price => 10)] }
  let!(:object) { double("Order", :line_items => line_items) }

  let!(:promotion_calculable) { double("Calculable", :promotion => promotion) }

  let!(:promotion) { double("Promotion", :rules => [double("Rule", :products => [product1])]) }
  let!(:promotion_without_rules) { double("Promotion", :rules => []) }
  let!(:promotion_without_products) { double("Promotion", :rules => [double("Rule", :products => [])]) }

  let!(:calculator) { Spree::Calculator::PercentPerItem.new(:preferred_percent => 25) }

  it "has a translation for description" do
    calculator.description.should_not include("translation missing")
    calculator.description.should == Spree.t(:percent_per_item)
  end

  it "correctly calculates per item promotion" do
    calculator.stub(:calculable => promotion_calculable)
    calculator.compute(object).to_f.should == 12.5
  end

  it "correctly calculates per item promotion without rules" do
    calculator.stub(:calculable => double("Calculable", :promotion => promotion_without_rules))
    calculator.compute(object).to_f.should == 15.0
  end

  it "correctly calculates per item promotion without products" do
    calculator.stub(:calculable => double("Calculable", :promotion => promotion_without_products))
    calculator.compute(object).to_f.should == 15.0
  end

  it "returns 0 when no object passed" do
    calculator.stub(:calculable => promotion_calculable)
    calculator.compute.should == 0
  end

  it "computes on promotion when promotion is present" do
    calculator.send(:compute_on_promotion?).should_not be_true
    calculator.stub(:calculable => promotion_calculable)
    calculator.send(:compute_on_promotion?).should be_true
  end

  # test that we do not fail when one promorule does not respond to products
  context "does not fail if a promotion rule does not respond to products" do
    before { promotion.stub :rules => [double("Rule", :products => [product1]), double("Rule")] }
    specify do
      calculator.stub(:calculable => promotion_calculable)
      expect { calculator.send(:matching_products) }.not_to raise_error
    end
  end

end
