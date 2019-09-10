require 'spec_helper'

describe Spree::Calculator::PercentOnLineItem, type: :model do
  let(:calculator) { Spree::Calculator::PercentOnLineItem.new }
  let(:line_item) { mock_model Spree::LineItem }

  before { allow(calculator).to receive_messages preferred_percent: 10 }

  context 'compute' do
    it 'rounds result correctly' do
      allow(line_item).to receive_messages amount: 31.08
      expect(calculator.compute(line_item)).to eq 3.11

      allow(line_item).to receive_messages amount: 31.00
      expect(calculator.compute(line_item)).to eq 3.10
    end

    it 'returns object.amount if computed amount is greater' do
      allow(line_item).to receive_messages amount: 30.00
      allow(calculator).to receive_messages preferred_percent: 110

      expect(calculator.compute(line_item)).to eq 30.0
    end
  end
end
