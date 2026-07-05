require 'spec_helper'

module Spree
  describe Cart::SetQuantity do
    subject { described_class }

    let(:store) { @default_store }
    let(:order) { create(:order, store: store) }
    let(:line_item) { create(:line_item, order: order) }

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
      it 'returns successful result', :aggregate_failures do
        result = subject.call(order: order, line_item: line_item, quantity: 5)

        expect(result.success).to eq(true)
        expect(result.value).to be_a LineItem
        expect(result.value.quantity).to eq(5)
      end
    end

    context 'stock reservations' do
      before do
        line_item.variant.stock_items.first.update!(backorderable: false)
        line_item.variant.stock_items.first.set_count_on_hand(20)
      end

      context 'when the order is mid-checkout' do
        before { order.update_column(:state, 'address') }

        it 'reserves the new quantity' do
          subject.call(order: order, line_item: line_item, quantity: 4)

          reservation = Spree::StockReservation.where(order_id: order.id, line_item_id: line_item.id).first
          expect(reservation).to be_present
          expect(reservation.quantity).to eq(4)
        end

        it 'updates an existing reservation in place rather than duplicating' do
          subject.call(order: order, line_item: line_item, quantity: 2)
          subject.call(order: order, line_item: line_item, quantity: 4)

          reservations = Spree::StockReservation.where(order_id: order.id, line_item_id: line_item.id)
          expect(reservations.count).to eq(1)
          expect(reservations.first.quantity).to eq(4)
        end

        it 'fails when the new quantity exceeds available stock and rolls back' do
          subject.call(order: order, line_item: line_item, quantity: 2)
          line_item.variant.stock_items.first.set_count_on_hand(3)

          result = subject.call(order: order, line_item: line_item, quantity: 5)

          expect(result).to be_failure
          expect(line_item.reload.quantity).to eq(2)
        end
      end

      context 'when the order is in the cart state' do
        it 'does not create a reservation' do
          expect {
            subject.call(order: order, line_item: line_item, quantity: 4)
          }.not_to change { Spree::StockReservation.count }
        end
      end
    end
  end
end
