require 'spec_helper'

RSpec.describe Spree::OrderStatusSubscriber do
  let(:order) { create(:completed_order_with_totals, store: @default_store) }

  it 'subscribes to every status-bearing record family' do
    expect(described_class.subscription_patterns).to include(
      'payment.completed', 'payment.voided', 'refund.created',
      'fulfillment.updated', 'return.received'
    )
  end

  it 'recomputes the owning order statuses when a return is received' do
    return_record = create(:approved_return, order: order, store: order.store)
    Spree::Returns::Receive.call(return_record: return_record)
    order.update_columns(fulfillment_status: nil)

    event = Spree::Event.new(name: 'return.received', payload: { 'id' => return_record.prefixed_id }, store_id: order.store_id)
    described_class.new.handle(event)

    expect(order.reload.fulfillment_status).to be_present
  end

  it 'recomputes the owning order statuses through the single writer' do
    payment = create(:payment, order: order, cart: nil, amount: order.total, status: 'completed')
    order.update_columns(payment_status: nil)

    event = Spree::Event.new(name: 'payment.completed', payload: { 'id' => payment.prefixed_id }, store_id: order.store_id)
    described_class.new.handle(event)

    expect(order.reload.payment_status).to be_present
  end

  it 'skips cart-owned records' do
    cart = create(:cart_with_line_items, store: @default_store)
    payment = create(:payment, order: nil, cart: cart, amount: 10)

    event = Spree::Event.new(name: 'payment.created', payload: { 'id' => payment.prefixed_id }, store_id: cart.store_id)

    expect { described_class.new.handle(event) }.not_to raise_error
  end

  # End to end through the event bus, not by calling handle() by hand: the
  # admin capture endpoint drives the payment machine directly, so the
  # after_transition publish is the only thing keeping the order's rollup
  # fresh — this is the wire that broke when a draft's payment settled but
  # the order kept saying none.
  it 'rolls the order up when a payment is captured through the machine', events: true do
    order = create(:order_with_line_items, store: @default_store)
    order.update_columns(status: 'draft', completed_at: nil)
    payment = create(:payment, order: order, cart: nil, amount: order.total, status: 'pending')
    order.update_columns(payment_status: 'none')

    payment.capture!

    expect(order.reload.payment_status).to eq('paid')
  end

  # The order used to be updated from two places at once — an after_save
  # callback on Payment and these events — so one capture recomputed it four
  # times. The whole duplication was invisible because events are disabled in
  # the test environment by default; these run with them on.
  describe 'recomputation count', events: true do
    let(:order) { create(:order_ready_to_ship, store: @default_store) }

    def count_recomputes
      count = 0
      allow_any_instance_of(Spree::Order).to receive(:update_statuses!).and_wrap_original do |method, *args|
        count += 1
        method.call(*args)
      end
      yield
      count
    end

    # Two, not three: payment.captured is skipped as the companion of
    # payment.completed. The remaining pair (completed + the save's own
    # updated) is deliberate — see the subscriber's comment.
    it 'recomputes twice for a capture rather than once per published event' do
      payment = order.payments.first
      payment.update_columns(status: 'pending')

      count = count_recomputes { Spree.payment_capture_workflow.call(payment: payment) }

      expect(count).to eq(2)
      expect(order.reload.payment_status).to eq('paid')
    end

    it 'counts each settlement when two payments settle in one request' do
      cart_order = create(:order_with_line_items, store: @default_store, line_items_count: 1)
      cart_order.update_columns(total: 100, item_total: 100)
      method = create(:check_payment_method, store: @default_store)
      first = create(:payment, order: cart_order, payment_method: method, amount: 60, status: 'pending')
      second = create(:payment, order: cart_order, payment_method: method, amount: 40, status: 'pending')

      first.complete!
      second.complete!

      expect(cart_order.reload.payment_total).to eq(100)
    end
  end
end
