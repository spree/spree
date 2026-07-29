require 'spec_helper'
require 'spree/testing_support/order_walkthrough'

module Spree
  describe Carts::Complete do
    subject { described_class.call(cart: cart) }

    let(:store) { @default_store }
    let(:cart) { ::OrderWalkthrough.up_to(:complete, store).cart || raise('walkthrough returned no cart') }

    # Build a payment-ready cart without completing it
    let(:ready_cart) do
      cart = ::OrderWalkthrough.up_to(:payment, store)
      FactoryBot.create(:payment, cart: cart, order: nil, payment_method: Spree::PaymentMethod.first, amount: cart.reload.total)
      cart
    end

    describe 'the three-phase pipeline' do
      subject { described_class.call(cart: ready_cart) }

      it 'completes the cart into a placed order' do
        result = subject

        expect(result).to be_success
        order = result.value
        expect(order).to be_a(Spree::Order)
        expect(order.status).to eq('placed')
        expect(order.completed_at).to be_present
        expect(order.cart_id).to eq(ready_cart.id)
        expect(ready_cart.reload.completed_at).to be_present
        expect(ready_cart.completing_at).to be_nil
      end

      it 'copies line items, fulfillments and addresses — never sharing rows' do
        order = subject.value

        expect(order.line_items.count).to eq(ready_cart.line_items.count)
        expect(order.line_items.ids).not_to match_array(ready_cart.line_items.ids)
        expect(order.fulfillments.count).to eq(ready_cart.reload.fulfillments.count)
        expect(order.ship_address_id).not_to eq(ready_cart.ship_address_id)
        expect(order.email).to eq(ready_cart.email)
        expect(order.token).to eq(ready_cart.token)
      end

      it 'is idempotent — replay returns the same order' do
        first = subject.value
        replay = described_class.call(cart: ready_cart.reload)

        expect(replay).to be_success
        expect(replay.value.id).to eq(first.id)
        expect(Spree::Order.where(cart_id: ready_cart.id).count).to eq(1)
      end

      it 'rejects a concurrent completion in flight' do
        ready_cart.update_columns(completing_at: Time.current)

        result = described_class.call(cart: ready_cart)
        expect(result).to be_failure
        expect(result.error.value[:code]).to eq('completion_in_progress')
      end

      it 'takes over a stale completion lock' do
        ready_cart.update_columns(completing_at: 10.minutes.ago)

        expect(subject).to be_success
      end

      it 'returns cart_changed on expected_total drift' do
        result = described_class.call(cart: ready_cart, expected_total: ready_cart.total + 5)

        expect(result).to be_failure
        expect(result.error.value[:code]).to eq('cart_changed')
        expect(ready_cart.reload.completed_at).to be_nil
      end

      it 'returns structured validation errors when requirements are unmet' do
        ready_cart.update_columns(email: nil)

        result = described_class.call(cart: ready_cart)
        expect(result).to be_failure
        expect(result.error.value[:code]).to eq('validation_failed')
        expect(result.error.value[:errors]).to be_present
      end
    end

    describe 'guest checkout policy' do
      it 'fails when the channel forbids guest checkout and the cart has no customer' do
        allow_any_instance_of(Spree::Checkout::Requirements).to receive(:call).and_return([])
        allow_any_instance_of(Spree::Cart).to receive(:guest_checkout_disallowed?).and_return(true)

        result = described_class.call(cart: ready_cart)
        expect(result).to be_failure
        expect(ready_cart.reload.completed_at).to be_nil
      end
    end

    describe 'stock reservations' do
      it 'releases reservations on successful completion' do
        line_item = ready_cart.line_items.first
        stock_item = line_item.variant.stock_items.first
        Spree::StockReservation.create!(cart: ready_cart, order: nil, line_item: line_item, stock_item: stock_item, quantity: 1, expires_at: 1.hour.from_now)

        expect { described_class.call(cart: ready_cart) }.to change { Spree::StockReservation.count }.by(-1)
      end
    end

    describe 'admin/B2B order path' do
      let(:order) { create(:order_with_line_items) }

      it 'finalizes a draft order through the same service' do
        create(:payment, order: order, amount: order.total, state: 'pending')

        result = described_class.call(cart: order)
        expect(result).to be_success
        expect(order.reload.completed_at).to be_present
      end
    end
  end
end
