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

      it 'rejects a variant discontinued after it entered the cart' do
        ready_cart.line_items.first.variant.update_columns(discontinue_on: 1.minute.ago)

        result = described_class.call(cart: ready_cart)

        expect(result).to be_failure
        expect(result.error.value[:code]).to eq('validation_failed')
        expect(result.error.value[:errors].map { |error| error[:code] }).to include('discontinued')
      end
    end

    describe 'guest checkout policy' do
      it 'fails when the channel forbids guest checkout and the cart has no customer' do
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

      it 'refuses a canceled draft order' do
        order.update_columns(status: 'canceled', canceled_at: Time.current)

        result = described_class.call(cart: order)
        expect(result).to be_failure
        expect(order.reload.completed_at).to be_nil
      end
    end

    describe 'payment failure compensation' do
      it 'rolls the draft order back and re-points money records to the cart' do
        # A payment that never completes: processing is a no-op, so coverage
        # stays below total and the pre-capture rollback arm fires.
        allow_any_instance_of(Spree::Payment).to receive(:process!)
        payment = ready_cart.payments.first

        result = described_class.call(cart: ready_cart)

        expect(result).to be_failure
        expect(result.error.value[:code]).to eq('payment_failed')
        expect(Spree::Order.where(cart_id: ready_cart.id)).to be_none
        expect(payment.reload.cart_id).to eq(ready_cart.id)
        expect(payment.order_id).to be_nil
        expect(ready_cart.reload.completing_at).to be_nil
        expect(ready_cart.completed_at).to be_nil
      end
    end

    describe 'net-terms completion (payment_pending)' do
      let(:uncovered_cart) { ::OrderWalkthrough.up_to(:payment, store) }

      it 'does not waive the payment requirement on carts — net terms is a draft-order flow' do
        result = described_class.call(cart: uncovered_cart, payment_pending: true)

        expect(result).to be_failure
        expect(result.error.value[:code]).to eq('validation_failed')
        expect(result.error.value[:errors].map { |error| error[:code] }).to include('payment_required')
      end

      it 'completes without capturing when the payment is authorized but pending' do
        uncovered_cart.payments.create!(payment_method: Spree::PaymentMethod.first, amount: uncovered_cart.total, state: 'pending')

        result = described_class.call(cart: uncovered_cart, payment_pending: true)

        expect(result).to be_success
        expect(result.value.status).to eq('placed')
        expect(result.value.payment_total).to eq(0)
      end
    end

    describe 'crash-window replay' do
      it 'heals a completion that died between the order commit and the cart stamp' do
        order = described_class.call(cart: ready_cart).value
        # Simulate the crash window: order placed, cart stamp lost
        # (update_all — the readonly completed-cart guard blocks AR writes).
        Spree::Cart.where(id: ready_cart.id).update_all(completed_at: nil, completing_at: Time.current)
        crashed_cart = Spree::Cart.find(ready_cart.id)

        result = described_class.call(cart: crashed_cart)

        expect(result).to be_success
        expect(result.value.id).to eq(order.id)
        expect(crashed_cart.reload.completed_at).to be_present
        expect(crashed_cart.completing_at).to be_nil
        expect(Spree::Order.where(cart_id: crashed_cart.id).count).to eq(1)
      end

      it 'returns a canceled order from a previous completion without re-finalizing' do
        order = described_class.call(cart: ready_cart).value
        order.update_columns(status: 'canceled', canceled_at: Time.current)

        result = described_class.call(cart: ready_cart.reload)

        expect(result).to be_success
        expect(result.value.status).to eq('canceled')
      end
    end

    describe 'before_finalize hook' do
      after { Spree.hooks.clear! }

      it 'dispatches with the workflow instance before the order places' do
        seen = nil
        Spree.hooks.register('carts.complete.before_finalize') do |flow|
          seen = { order_placed: flow.order.placed?, cart_id: flow.cart.id }
        end

        described_class.call(cart: ready_cart)

        expect(seen).to eq(order_placed: false, cart_id: ready_cart.id)
      end
    end

    describe 'coupon codes' do
      it 're-points an applied cart coupon code to the order and marks it used' do
        promotion = create(:promotion_with_item_adjustment, adjustment_rate: 2, kind: :coupon_code, store: store, multi_codes: true, number_of_codes: 1)
        coupon_code = promotion.coupon_codes.first
        coupon_code.update!(cart: ready_cart)
        ready_cart.update_columns(coupon_code: coupon_code.code)

        result = described_class.call(cart: ready_cart)

        expect(result).to be_success
        expect(coupon_code.reload.state).to eq('used')
        expect(coupon_code.order_id).to eq(result.value.id)
        expect(coupon_code.cart_id).to be_nil
      end

      it 'detaches codes whose promotion did not apply' do
        promotion = create(:promotion, kind: :coupon_code, store: store)
        coupon_code = create(:coupon_code, promotion: promotion, cart: ready_cart)

        result = described_class.call(cart: ready_cart)

        expect(result).to be_success
        expect(coupon_code.reload.state).to eq('unused')
        expect(coupon_code.order_id).to be_nil
      end
    end
  end
end
