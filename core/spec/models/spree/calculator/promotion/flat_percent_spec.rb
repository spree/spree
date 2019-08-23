require 'spec_helper'

describe Spree::Calculator::Promotion::FlatPercent, type: :model do
  let(:calculator) { Spree::Calculator::Promotion::FlatPercent.new }
  let(:line_item) { mock_model Spree::LineItem }

  before { allow(calculator).to receive_messages preferred_percent: 10 }

  context 'compute' do
    it 'rounds result correctly' do
      allow(line_item).to receive_messages amount: 31.08
      expect(calculator.compute(line_item)).to eq 3.1079999999999997

      allow(line_item).to receive_messages amount: 31.00
      expect(calculator.compute(line_item)).to eq 3.10
    end
  end
end
