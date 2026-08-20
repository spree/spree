require 'spec_helper'

module Spree
  describe Carts::Destroy do
    subject { described_class.call cart: cart }

    context 'when a cart is given' do
      context 'when it can be destroyed' do
        let(:cart) do
          create(:cart_with_line_items, line_items_count: 2, ship_address: ship_address, bill_address: bill_address)
        end
        let!(:fulfillment) { create(:fulfillment, cart: cart, order: nil) }
        let!(:payment) { create(:payment, amount: cart.total, cart: cart, order: nil) }
        let!(:line_item_ids) { cart.line_item_ids }
        let!(:fulfillment_ids) { cart.fulfillment_ids }
        let!(:payment_ids) { cart.payment_ids }

        let(:ship_address) { create(:address) }
        let(:bill_address) { create(:address) }
        let(:address_ids) { [ship_address.id, bill_address.id] }

        # The factory's recalculate_totals! caches empty association sets on
        # the cart instance before the let! rows above exist.
        before { cart.reload }

        it 'returns success' do
          expect(subject.success?).to be true
        end

        it 'voids pending payments' do
          expect_any_instance_of(Spree::Payment).to receive(:void!).exactly(cart.payments.count).times

          subject
        end

        # The cart is destroyed along with them, so the observable fact is that
        # each one was canceled on its way out rather than deleted outright.
        it 'cancels unfulfilled fulfillments' do
          statuses = []
          allow_any_instance_of(Spree::Fulfillment).to receive(:update!) do |fulfillment, attributes|
            statuses << attributes[:status]
            fulfillment.update_columns(attributes)
          end

          subject

          expect(statuses).to all(eq('canceled'))
          expect(statuses.count).to eq(1)
        end

        it 'destroys the cart' do
          expect(cart.destroyed?).not_to be true

          subject

          expect(cart.destroyed?).to be true
        end

        it 'destroys line_items, addresses, fulfillments and payments' do
          subject

          expect(Spree::LineItem.where(id: line_item_ids)).to be_empty
          expect(Spree::Fulfillment.where(id: fulfillment_ids)).to be_empty
          expect(Spree::Payment.where(id: payment_ids)).to be_empty
          expect(Spree::Address.where(id: address_ids)).to be_empty
        end

        context 'with stock reservations' do
          let(:line_item) { cart.line_items.first }
          let!(:reservation) do
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

          it 'destroys the reservations via dependent: :destroy on the cart' do
            reservation_id = reservation.id
            subject
            expect(Spree::StockReservation.where(id: reservation_id)).to be_empty
          end
        end

        context 'when addresses are assigned to other records' do
          let!(:other_order) { create(:order_ready_to_ship, ship_address: ship_address, bill_address: bill_address) }

          it 'destroys the cart' do
            expect(cart.destroyed?).not_to be true

            subject

            expect(cart.destroyed?).to be true
          end

          it 'destroys line_items, fulfillments and payments, but keeps addresses' do
            subject

            expect(Spree::LineItem.where(id: line_item_ids)).to be_empty
            expect(Spree::Fulfillment.where(id: fulfillment_ids)).to be_empty
            expect(Spree::Payment.where(id: payment_ids)).to be_empty

            expect(Spree::Address.where(id: address_ids)).to contain_exactly(ship_address, bill_address)
          end
        end

        context 'when empty service is called first' do
          before { Spree::Carts::Empty.call(cart: cart) }

          it 'destroys the cart' do
            expect(cart.destroyed?).not_to be true

            subject

            expect(cart.destroyed?).to be true
          end
        end
      end

      context 'when it cannot be destroyed' do
        context 'because the cart is completed' do
          let(:cart) { create(:cart_with_line_items).tap { |record| record.update_columns(completed_at: Time.current) } }

          it 'returns failure' do
            expect(subject.success?).to be false
            expect(subject.error.value).to eq Spree.t(:cannot_be_destroyed)
          end
        end

        context 'because a payment is completed' do
          let(:cart) { create(:cart_with_line_items) }
          let!(:payment) { create(:payment, cart: cart, order: nil, status: 'completed', amount: cart.total) }

          it 'returns failure' do
            expect(subject.success?).to be false
            expect(subject.error.value).to eq Spree.t(:cannot_be_destroyed)
          end
        end
      end
    end

    context 'when nil is given' do
      let(:cart) { nil }

      before { subject }

      it 'returns failure' do
        expect(subject.success?).to be false
        expect(subject.error.value).to eq Spree.t(:cannot_be_destroyed)
      end
    end
  end
end
