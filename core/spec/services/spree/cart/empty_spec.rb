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
  end
end
