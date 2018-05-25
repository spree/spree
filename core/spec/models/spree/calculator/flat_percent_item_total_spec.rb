require 'spec_helper'

describe Spree::Calculator::FlatPercentItemTotal, type: :model do
  let(:calculator) { Spree::Calculator::FlatPercentItemTotal.new }
  let(:line_item) { mock_model Spree::LineItem }
  let(:order) { create(:order_with_line_items, line_items_count: 2) }

  before { allow(calculator).to receive_messages preferred_flat_percent: 10 }

  context 'compute' do
    it 'rounds result correctly' do
      allow(line_item).to receive_messages promotionable_amount: 31.08
      expect(calculator.compute(line_item)).to eq 3.11

      allow(line_item).to receive_messages promotionable_amount: 31.00
      expect(calculator.compute(line_item)).to eq 3.10
    end

    it 'returns object.promotionable_items_amount if computed amount is greater' do
      allow(calculator).to receive_messages preferred_flat_percent: 110
      allow(line_item).to receive_messages promotionable_amount: 30.00

      expect(calculator.compute(line_item)).to eq 30.0
    end

    it 'calculates only for promotionable items' do
      order.products.first.update_column(:promotionable, false)
      allow(calculator).to receive_messages preferred_flat_percent: 50

      expect(calculator.compute(order)).to eq 5
    end
  end
end
