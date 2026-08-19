require 'spec_helper'

module Spree
  describe Carts::Empty do
    subject { described_class.call cart: cart }

    context 'when a cart is given' do
      let(:cart) { create(:cart_with_line_items, line_items_count: 2) }
      let(:promotion) { create(:promotion, code: '10off') }

      before do
        Spree::OrderPromotion.create!(cart: cart, promotion: promotion)
      end

      context 'completed cart' do
        before do
          cart.update_columns(completed_at: Time.current)
          cart.reload
        end

        it 'returns failure' do
          expect(subject.success?).to be false
          expect(subject.value).to eq Spree.t(:cannot_empty)
        end
      end

      context 'incomplete cart' do
        before { subject }

        it 'returns success' do
          expect(subject.success?).to be true
          expect(subject.value).to eq(cart)
        end

        it 'clears out line items, typed rows and totals' do
          expect(cart.line_items.count).to be_zero
          expect(cart.discounts.count).to be_zero
          expect(cart.fulfillments.count).to be_zero
          expect(cart.order_promotions.count).to be_zero
          expect(cart.discount_total).to be_zero
          expect(cart.item_total).to be_zero
          expect(cart.delivery_total).to be_zero
          expect(cart.total_quantity).to be_zero
        end
      end
    end

    context 'when nil is given' do
      let(:cart) { nil }

      before { subject }

      it 'returns failure' do
        expect(subject.success?).to be false
        expect(subject.value).to eq Spree.t(:cannot_empty)
      end
    end

    context 'with stock reservations' do
      let(:cart) { create(:cart_with_line_items, line_items_count: 1) }
      let(:line_item) { cart.line_items.first }

      before do
        line_item.variant.stock_levels.first.update!(backorderable: false)
        line_item.variant.stock_levels.first.set_count_on_hand(10)
        create(
          :stock_reservation,
          stock_level: line_item.variant.stock_levels.first,
          line_item: line_item,
          cart: cart,
          quantity: line_item.quantity,
          expires_at: 5.minutes.from_now
        )
      end

      it 'releases all reservations belonging to the cart' do
        expect { described_class.call(cart: cart) }
          .to change { Spree::StockReservation.where(cart_id: cart.id).count }.from(1).to(0)
      end
    end
  end
end
