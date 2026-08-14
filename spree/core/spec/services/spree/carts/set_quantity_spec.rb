require 'spec_helper'

module Spree
  describe Carts::SetQuantity do
    subject { described_class }

    let(:store) { @default_store }
    let(:cart) { create(:cart, store: store) }
    let(:line_item) { create(:line_item, cart: cart, order: nil) }

    context 'with non-backorderable item' do
      before do
        line_item.variant.stock_items.first.update(backorderable: false)
        line_item.variant.stock_items.first.update(count_on_hand: 5)
      end

      context 'with sufficient stock quantity' do
        it 'returns successful result', :aggregate_failures do
          result = subject.call(cart: cart, line_item: line_item, quantity: 5)

          expect(result.success).to eq(true)
          expect(result.value).to be_a LineItem
          expect(result.value.quantity).to eq(5)
        end
      end

      context 'with insufficient stock quantity' do
        it 'returns result with success equal false', :aggregate_failures do
          result = subject.call(cart: cart, line_item: line_item, quantity: 10)

          expect(result.success).to eq(false)
          expect(result.value).to be_a LineItem
          expect(result.error.to_s).to eq("Quantity selected of \"#{line_item.name}\" is not available.")
        end
      end
    end

    context 'with backorderable item' do
      it 'returns successful result', :aggregate_failures do
        result = subject.call(cart: cart, line_item: line_item, quantity: 5)

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

      context 'when the cart is mid-checkout' do
        before { cart.update_columns(email: 'buyer@example.com') }

        it 'reserves the new quantity' do
          subject.call(cart: cart, line_item: line_item, quantity: 4)

          reservation = Spree::StockReservation.where(cart_id: cart.id, line_item_id: line_item.id).first
          expect(reservation).to be_present
          expect(reservation.quantity).to eq(4)
        end

        it 'updates an existing reservation in place rather than duplicating' do
          subject.call(cart: cart, line_item: line_item, quantity: 2)
          subject.call(cart: cart, line_item: line_item, quantity: 4)

          reservations = Spree::StockReservation.where(cart_id: cart.id, line_item_id: line_item.id)
          expect(reservations.count).to eq(1)
          expect(reservations.first.quantity).to eq(4)
        end

        it 'fails when the new quantity exceeds available stock and rolls back' do
          subject.call(cart: cart, line_item: line_item, quantity: 2)
          line_item.variant.stock_items.first.set_count_on_hand(3)

          result = subject.call(cart: cart, line_item: line_item, quantity: 5)

          expect(result).to be_failure
          expect(line_item.reload.quantity).to eq(2)
        end
      end

      context 'when the cart is not yet in checkout' do
        it 'does not create a reservation' do
          expect {
            subject.call(cart: cart, line_item: line_item, quantity: 4)
          }.not_to change { Spree::StockReservation.count }
        end
      end
    end

    # The workflow this shim delegates to removes the row on a zero quantity,
    # so a naive `line_item.reload` here would raise instead of returning a
    # result — the contract legacy callers were written against.
    describe 'a zero quantity' do
      it 'removes the line item and still returns a result' do
        line_item # the shim needs it to exist before the baseline is taken
        result = nil

        expect { result = subject.call(cart: cart, line_item: line_item, quantity: 0) }.
          to change { cart.reload.line_items.count }.by(-1)

        expect(result).to be_success
      end
    end

    # The cart-side workflow turns a vetoed item into a warning and succeeds.
    # This service's callers predate that, so it has to report the failure.
    describe 'a rejected quantity change' do
      after { Spree.hooks.clear! }

      it 'returns a failure' do
        Spree.hooks.register('carts.upsert_items.validate') { |flow| flow.reject!('over the limit') }

        result = subject.call(cart: cart, line_item: line_item, quantity: 3)

        expect(result).to be_failure
        expect(result.error.to_s).to eq('over the limit')
      end
    end

  end
end
