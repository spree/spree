require 'spec_helper'

RSpec.describe Spree::OrderStatusSubscriber do
  let(:order) { create(:completed_order_with_totals, store: @default_store) }

  it 'subscribes to every status-bearing record family' do
    expect(described_class.subscription_patterns).to include(
      'payment.completed', 'payment.voided', 'refund.created',
      'fulfillment.updated', 'return_item.received'
    )
  end

  it 'recomputes the owning order statuses through the single writer' do
    payment = create(:payment, order: order, cart: nil, amount: order.total, state: 'completed')
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
end
