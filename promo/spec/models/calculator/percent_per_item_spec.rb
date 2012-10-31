require 'spec_helper'

describe Spree::Calculator::PercentPerItem do
  # Like an order object, but not quite...
  let!(:product1) { double("Product") }
  let!(:product2) { double("Product") }
  let!(:line_items) { [double("LineItem", :quantity => 5, :product => product1, :price => 10), double("LineItem", :quantity => 1, :product => product2, :price => 10)] }
  let!(:object) { double("Order", :line_items => line_items) }

  let!(:promotion_calculable) { double("Calculable", :promotion => promotion) }

  let!(:promotion) { double("Promotion", :rules => [double("Rule", :products => [product1])]) }

  let!(:calculator) { Spree::Calculator::PercentPerItem.new(:preferred_percent => 0.25) }

  it "has a translation for description" do
    calculator.description.should_not include("translation missing")
    calculator.description.should == I18n.t(:percent_per_item)
  end

  it "correctly calculates per item promotion" do
    calculator.stub(:calculable => promotion_calculable)
    calculator.compute(object).to_f.should == 12.5 # 5 x 10 x 0.25 since only product1 is included in the promotion rule
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

end
