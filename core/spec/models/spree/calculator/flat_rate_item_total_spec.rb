require 'spec_helper'

describe Spree::Calculator::FlatRateItemTotal, type: :model do
  let(:calculator) { Spree::Calculator::FlatRateItemTotal.new }
  let!(:order) { create(:order) }
  let!(:line_item) { create(:line_item, currency: 'USD', price: 100, quantity: 1, order: order) }

  context 'compute' do
    context 'when given an order with correct currency' do
      let!(:line_item_1) { line_item }
      let!(:line_item_2) { create(:line_item, price: 10, quantity: 3) }

      before do
        allow(order).to receive_messages line_items: [line_item_1, line_item_2]
      end

      context 'computes the discount amount correctly' do
        it 'is 7.69' do
          calculator.preferred_amount = 10
          calculator.preferred_currency = 'USD'

          expect(calculator.compute(line_item).round(2)).to eq(7.69)
        end
      end
    end

    context 'when given an order with the incorrect currency' do
      let!(:line_item_1) { line_item }
      let!(:line_item_2) { create(:line_item, price: 10, quantity: 3) }

      before do
        allow(order).to receive_messages line_items: [line_item_1, line_item_2]
      end

      it "Returns 0" do
        calculator.preferred_amount = 10
        calculator.preferred_currency = 'GBP'

        expect(calculator.compute(line_item).round(2)).to eq(0)
      end
    end

    context 'when given an order with no currency' do
      let!(:line_item_1) { line_item }
      let!(:line_item_2) { create(:line_item, price: 10, quantity: 3) }

      before do
        allow(order).to receive_messages line_items: [line_item_1, line_item_2]
      end

      it "Returns 0" do
        calculator.preferred_amount = 10
        calculator.preferred_currency = ''

        expect(calculator.compute(line_item).round(2)).to eq(0)
      end
    end

    context 'when given an order with no amount' do
      let!(:line_item_1) { line_item }
      let!(:line_item_2) { create(:line_item, price: 10, quantity: 3) }

      before do
        allow(order).to receive_messages line_items: [line_item_1, line_item_2]
      end

      it "Returns 0" do
        calculator.preferred_amount = 10
        calculator.preferred_currency = ''

        expect(calculator.compute.round(2)).to eq(0)
      end
    end

  end
end
