require 'spec_helper'

describe Spree::Calculator::PriceSack do
  let(:calculator) do
    calculator = Spree::Calculator::PriceSack.new
    calculator.preferred_minimal_amount = 5
    calculator.preferred_normal_amount = 10
    calculator.preferred_discount_amount = 1
    calculator
  end

  let(:order) { stub_model(Spree::Order) }
  let(:shipment) { stub_model(Spree::Shipment) }

  # Regression test for #714 and #739
  it "computes with an order object" do
    calculator.compute(order)
  end

  # Regression test for #1156
  it "computes with a snipment object" do
    calculator.compute(shipment)
  end

  # Regression test for #2055
  it "computes the correct amount" do
    calculator.compute(2).should == calculator.preferred_normal_amount
    calculator.compute(6).should == calculator.preferred_discount_amount
  end
end
