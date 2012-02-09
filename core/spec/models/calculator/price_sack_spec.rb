require 'spec_helper'

describe Spree::Calculator::PriceSack do
  let(:calculator) { Spree::Calculator::PriceSack.new }
  let(:order) { stub_model(Spree::Order) }

  # Regression test for #714 and #739
  it "computes with an order object" do
    calculator.compute(order)
  end
end
