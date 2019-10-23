require 'spec_helper'

describe Spree::Calculator::FlatPercentItemTotal, type: :model do
  let(:calculator) { Spree::Calculator::FlatPercentItemTotal.new }
  let(:order) { mock_model Spree::Order }

  before { allow(calculator).to receive_messages preferred_flat_percent: 10 }

  context 'compute' do
    it 'rounds result correctly' do
      allow(order).to receive_messages amount: 31.08
      expect(calculator.compute(order)).to eq 3.11

      allow(order).to receive_messages amount: 31.00
      expect(calculator.compute(order)).to eq 3.10
    end

    it 'returns object.amount if computed amount is greater' do
      allow(order).to receive_messages amount: 30.00
      allow(calculator).to receive_messages preferred_flat_percent: 110

      expect(calculator.compute(order)).to eq 30.0
    end
  end
end
