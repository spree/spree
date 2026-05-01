require 'spec_helper'

module Spree
  describe Cart::Empty do
    subject { described_class.call order: order }

    context 'when order is given' do
      let(:order) { Spree::Order.create(email: 'test@example.com') }
      let(:promotion) { create :promotion, code: '10off' }

      before do
        promotion.orders << order
      end

      context 'completed order' do
        before do
          order.update_columns(state: 'complete', completed_at: Time.current)
        end

        it 'returns failure' do
          expect(subject.success?).to be false
          expect(subject.value).to eq Spree.t(:cannot_empty)
        end
      end

      context 'incomplete order' do
        before { subject }

        it 'returns success' do
          expect(subject.success?).to be true
          expect(subject.value).to eq(order)
        end

        it 'clears out line items, adjustments and update totals' do
          expect(order.line_items.count).to be_zero
          expect(order.adjustments.count).to be_zero
          expect(order.shipments.count).to be_zero
          expect(order.order_promotions.count).to be_zero
          expect(order.promo_total).to be_zero
          expect(order.item_total).to be_zero
          expect(order.ship_total).to be_zero
        end
      end
    end

    context 'when nil is given' do
      let(:order) { nil }

      before { subject }

      it 'returns failure' do
        expect(subject.success?).to be false
        expect(subject.value).to eq Spree.t(:cannot_empty)
      end
    end

    context 'with stock reservations' do
      let(:order) { create(:order_with_line_items, line_items_count: 1) }
      let(:line_item) { order.line_items.first }

      before do
        line_item.variant.stock_items.first.update!(backorderable: false)
        line_item.variant.stock_items.first.set_count_on_hand(10)
        create(
          :stock_reservation,
          stock_item: line_item.variant.stock_items.first,
          line_item: line_item,
          order: order,
          quantity: line_item.quantity,
          expires_at: 5.minutes.from_now
        )
      end

      it 'releases all reservations belonging to the order' do
        expect { described_class.call(order: order) }
          .to change { Spree::StockReservation.where(order_id: order.id).count }.from(1).to(0)
      end
    end
  end
end
