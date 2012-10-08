require 'spec_helper'

describe Spree::Calculator::PriceSack do
  let(:calculator) { Spree::Calculator::PriceSack.new }
  let(:order) { stub_model(Spree::Order) }
  let(:shipment) { stub_model(Spree::Shipment) }

  # Regression test for #714 and #739
  it "computes with an order object" do
    calculator.compute(order)
  end

  # Regression test for #1156
  it "computes with a shipment object" do
    calculator.compute(shipment)
  end
end
