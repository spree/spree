require 'spec_helper'

describe Spree::Calculator::PriceSack, type: :model do
  let(:calculator) do
    calculator = Spree::Calculator::PriceSack.new
    calculator.preferred_minimal_amount = 5
    calculator.preferred_normal_amount = 10
    calculator.preferred_discount_amount = 1
    calculator
  end

  let(:order) { stub_model(Spree::Order) }
  let(:shipment) { stub_model(Spree::Shipment, amount: 10) }

  # Regression test for #714 and #739
  it 'computes with an order object' do
    calculator.compute(order)
  end

  # Regression test for #1156
  it 'computes with a shipment object' do
    calculator.compute(shipment)
  end

  # Regression test for #2055
  it 'computes the correct amount' do
    expect(calculator.compute(2)).to eq(calculator.preferred_normal_amount)
    expect(calculator.compute(6)).to eq(calculator.preferred_discount_amount)
  end
end
