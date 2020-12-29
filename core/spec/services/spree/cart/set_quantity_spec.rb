require 'spec_helper'

module Spree
  describe Cart::SetQuantity do
    subject { described_class }

    let!(:order) { Spree::Order.create }
    let!(:line_item) { create(:line_item, order: order) }

    context 'with non-backorderable item' do
      before do
        line_item.variant.stock_items.first.update(backorderable: false)
        line_item.variant.stock_items.first.update(count_on_hand: 5)
      end

      context 'with sufficient stock quantity' do
        it 'returns successful result', :aggregate_failures do
          result = subject.call(order: order, line_item: line_item, quantity: 5)

          expect(result.success).to eq(true)
          expect(result.value).to be_a LineItem
          expect(result.value.quantity).to eq(5)
        end
      end

      context 'with insufficient stock quantity' do
        it 'return result with success equal false', :aggregate_failures do
          result = subject.call(order: order, line_item: line_item, quantity: 10)

          expect(result.success).to eq(false)
          expect(result.value).to be_a LineItem
          expect(result.error.to_s).to eq("Quantity selected of \"#{line_item.name}\" is not available.")
        end
      end
    end

    context 'with backorderable item' do
      it 'returns successfull result', :aggregate_failures do
        result = subject.call(order: order, line_item: line_item, quantity: 5)

        expect(result.success).to eq(true)
        expect(result.value).to be_a LineItem
        expect(result.value.quantity).to eq(5)
      end
    end
  end
end
