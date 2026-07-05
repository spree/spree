require 'spec_helper'

module Spree
  describe Cart::RemoveLineItem do
    subject { described_class }

    let(:order) { create :order, line_items: [line_item] }
    let(:line_item) { create :line_item, variant: variant, price: nil, quantity: 10 }
    let(:variant) { create :variant, price: 20 }
    let(:execute) { subject.call order: order, line_item: line_item }
    let(:value) { execute.value }

    context 'remove line item' do
      context 'with any quantity' do
        it 'with any quantity' do
          expect(order.amount).to eq 200
          expect { execute }.to change { order.line_items.count }.by(-1)
          expect(execute).to be_success
          expect(value).to eq line_item
          expect(order.amount).to eq 0
        end
      end

      context 'with many unique items' do
        let(:order) { create(:order_with_line_items, line_items_count: 2) }
        let(:line_item) {order.line_items.first}

        it 'from order with many unique items' do
          expect(order.amount).to eq 20
          expect(order.line_items.count).to eq 2
          expect { execute }.to change { order.line_items.count }.by(-1)
          expect(execute).to be_success
          expect(value).to eq line_item
          expect(order.amount).to eq 10
        end
      end
    end

    context 'given a shipment' do
      let(:shipment) { create :shipment }
      let(:options) { { shipment: shipment } }
      let(:execute) { subject.call order: order, line_item: line_item, options: options }

      it 'ensure shipment calls update_amounts instead of order calling ensure_updated_shipments' do
        expect(order).not_to receive(:ensure_updated_shipments)
        expect(shipment).to receive(:update_amounts)
        expect(execute).to be_success
      end
    end

    context 'not given a shipment' do
      let(:execute) { subject.call order: order, line_item: line_item }

      it 'ensures updated shipments' do
        expect(order).to receive(:ensure_updated_shipments)
        expect(execute).to be_success
      end
    end

    context 'stock reservations' do
      let(:order) { create(:order_with_line_items, line_items_count: 2) }
      let(:line_item) { order.line_items.first }
      let(:other_line_item) { order.line_items.last }

      before do
        order.line_items.each do |li|
          li.variant.stock_items.first.update!(backorderable: false)
          li.variant.stock_items.first.set_count_on_hand(10)
        end
      end

      context 'when the order is mid-checkout' do
        before { order.update_column(:state, 'address') }

        it 'reservation for the removed line item is destroyed via dependent: :destroy' do
          create(
            :stock_reservation,
            stock_item: line_item.variant.stock_items.first,
            line_item: line_item,
            order: order,
            quantity: line_item.quantity,
            expires_at: 5.minutes.from_now
          )

          expect { subject.call(order: order, line_item: line_item) }
            .to change { Spree::StockReservation.where(order_id: order.id, line_item_id: line_item.id).count }
            .from(1).to(0)
        end

        it 'remaining line items get a fresh reservation pass' do
          create(
            :stock_reservation,
            stock_item: other_line_item.variant.stock_items.first,
            line_item: other_line_item,
            order: order,
            quantity: other_line_item.quantity,
            expires_at: 1.minute.from_now
          )
          original_expiry = Spree::StockReservation.find_by(line_item_id: other_line_item.id).expires_at

          Timecop.freeze(2.minutes.from_now) do
            subject.call(order: order, line_item: line_item)
          end

          new_expiry = Spree::StockReservation.find_by(line_item_id: other_line_item.id).expires_at
          expect(new_expiry).to be > original_expiry
        end

        it 'leaves no orphaned reservations after removing every line item' do
          # Removing the second-to-last item still triggers a Reserve pass over
          # the remaining one. Removing the last item must not leave any
          # reservation rows behind for this order.
          subject.call(order: order, line_item: line_item)
          subject.call(order: order, line_item: other_line_item.reload)

          expect(Spree::StockReservation.where(order_id: order.id)).to be_empty
        end

        it 'returns failure and rolls back the destroy when re-reservation fails' do
          # Bump the remaining item's quantity above its stock so re-reservation
          # after the destroy fails. count_on_hand stays > 0 so select_stock_item
          # still picks the row.
          other_line_item.update_column(:quantity, 5)
          other_line_item.variant.stock_items.first.set_count_on_hand(2)
          line_item_count_before = order.line_items.count

          result = subject.call(order: order, line_item: line_item)

          expect(result).to be_failure
          expect(result.error.to_s).to include('available')
          expect(order.reload.line_items.count).to eq(line_item_count_before)
        end
      end

      context 'when the order is in the cart state' do
        it 'does not run a reservation pass' do
          expect {
            subject.call(order: order, line_item: line_item)
          }.not_to change { Spree::StockReservation.count }
        end
      end
    end
  end
end
