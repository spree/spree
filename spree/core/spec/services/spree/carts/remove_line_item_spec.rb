require 'spec_helper'

module Spree
  describe Carts::RemoveLineItem do
    subject { described_class }

    let(:cart) { create(:cart) }
    let!(:line_item) { create(:line_item, cart: cart, order: nil, variant: variant, price: nil, quantity: 10) }
    let(:variant) { create(:variant, price: 20) }
    let(:execute) { subject.call cart: cart, line_item: line_item }
    let(:value) { execute.value }

    before { cart.recalculate_totals! }

    context 'remove line item' do
      context 'with any quantity' do
        it 'removes the whole line item' do
          expect(cart.reload.item_total).to eq 200
          expect { execute }.to change { cart.line_items.count }.by(-1)
          expect(execute).to be_success
          expect(value).to eq line_item
          expect(cart.reload.item_total).to eq 0
        end
      end

      context 'with many unique items' do
        let(:cart) { create(:cart_with_line_items, line_items_count: 2) }
        let!(:line_item) { cart.line_items.first }

        it 'removes only the given line item' do
          expect(cart.reload.item_total).to eq 20
          expect(cart.line_items.count).to eq 2
          expect { execute }.to change { cart.line_items.count }.by(-1)
          expect(execute).to be_success
          expect(value).to eq line_item
          expect(cart.reload.item_total).to eq 10
        end
      end
    end

    context 'not given a fulfillment' do
      it 'ensures updated fulfillments' do
        expect(cart).to receive(:ensure_updated_fulfillments)
        expect(execute).to be_success
      end
    end

    context 'stock reservations' do
      let(:cart) { create(:cart_with_line_items, line_items_count: 2) }
      let!(:line_item) { cart.line_items.first }
      let(:other_line_item) { cart.line_items.last }

      before do
        cart.line_items.each do |cart_line_item|
          cart_line_item.variant.stock_items.first.update!(backorderable: false)
          cart_line_item.variant.stock_items.first.set_count_on_hand(10)
        end
      end

      context 'when the cart is mid-checkout' do
        before { cart.update_columns(email: 'buyer@example.com') }

        it 'reservation for the removed line item is destroyed via dependent: :destroy' do
          create(
            :stock_reservation,
            stock_item: line_item.variant.stock_items.first,
            line_item: line_item,
            cart: cart,
            quantity: line_item.quantity,
            expires_at: 5.minutes.from_now
          )

          expect { subject.call(cart: cart, line_item: line_item) }
            .to change { Spree::StockReservation.where(cart_id: cart.id, line_item_id: line_item.id).count }
            .from(1).to(0)
        end

        it 'remaining line items get a fresh reservation pass' do
          create(
            :stock_reservation,
            stock_item: other_line_item.variant.stock_items.first,
            line_item: other_line_item,
            cart: cart,
            quantity: other_line_item.quantity,
            expires_at: 1.minute.from_now
          )
          original_expiry = Spree::StockReservation.find_by(line_item_id: other_line_item.id).expires_at

          Timecop.freeze(2.minutes.from_now) do
            subject.call(cart: cart, line_item: line_item)
          end

          new_expiry = Spree::StockReservation.find_by(line_item_id: other_line_item.id).expires_at
          expect(new_expiry).to be > original_expiry
        end

        it 'leaves no orphaned reservations after removing every line item' do
          # Removing the second-to-last item still triggers a Reserve pass over
          # the remaining one. Removing the last item must not leave any
          # reservation rows behind for this cart.
          subject.call(cart: cart, line_item: line_item)
          subject.call(cart: cart, line_item: other_line_item.reload)

          expect(Spree::StockReservation.where(cart_id: cart.id)).to be_empty
        end

        it 'returns failure and rolls back the destroy when re-reservation fails' do
          # Bump the remaining item's quantity above its stock so re-reservation
          # after the destroy fails. count_on_hand stays > 0 so select_stock_item
          # still picks the row.
          other_line_item.update_column(:quantity, 5)
          other_line_item.variant.stock_items.first.set_count_on_hand(2)
          line_item_count_before = cart.line_items.count

          result = subject.call(cart: cart, line_item: line_item)

          expect(result).to be_failure
          expect(result.error.to_s).to include('available')
          expect(cart.reload.line_items.count).to eq(line_item_count_before)
        end
      end

      context 'when the cart is not yet in checkout' do
        it 'does not run a reservation pass' do
          expect {
            subject.call(cart: cart, line_item: line_item)
          }.not_to change { Spree::StockReservation.count }
        end
      end
    end
  end
end
