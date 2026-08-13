require 'spec_helper'

RSpec.describe Spree::DerivedNumber do
  let(:order) { create(:order) }

  describe 'fulfillments' do
    it 'derives the number from the order and position' do
      first = create(:fulfillment, order: order)
      second = create(:fulfillment, order: order)

      expect([first.number, second.number]).to eq(["#{order.number}-F1", "#{order.number}-F2"])
    end

    it 'does not write the column' do
      fulfillment = create(:fulfillment, order: order)

      expect(fulfillment.reload[:number]).to be_nil
    end

    it 'keeps a stored number on legacy rows' do
      fulfillment = create(:fulfillment, order: order)
      fulfillment.update_column(:number, 'F00012345678')

      expect(fulfillment.reload.number).to eq('F00012345678')
    end

    it 'keeps positions stable when an earlier sibling is canceled' do
      first = create(:fulfillment, order: order)
      second = create(:fulfillment, order: order)
      first.update!(status: 'canceled')

      expect(second.number).to eq("#{order.number}-F2")
    end
  end

  describe 'payments' do
    let(:paid_order) { create(:order, total: 45.75) }

    it 'derives the number from the order and position' do
      payment = create(:payment, order: paid_order)

      expect(payment.number).to eq("#{paid_order.number}-P1")
    end

    it 'numbers a second payment on the same order' do
      create(:payment, order: paid_order)
      second = create(:payment, order: paid_order, amount: 0)

      expect(second.number).to eq("#{paid_order.number}-P2")
    end

    it 'derives from the cart while checkout is still in progress' do
      cart = create(:cart)
      payment = create(:payment, cart: cart, order: nil, amount: 0)

      expect(payment.number).to eq("#{cart.number}-P1")
    end
  end

  describe 'gateway options' do
    let(:payment) { create(:payment, order: create(:order, total: 45.75)) }

    it 'sends the payment number as the gateway order reference' do
      expect(payment.gateway_options[:order_id]).to eq(payment.number)
    end

    it 'builds the idempotency key from the immutable prefixed id' do
      expect(payment.gateway_options[:idempotency_key]).to eq("spree-#{payment.prefixed_id}")
    end

    it 'keeps the idempotency key stable when an earlier sibling is destroyed' do
      paid_order = create(:order, total: 45.75)
      first = create(:payment, order: paid_order)
      second = create(:payment, order: paid_order, amount: 0)
      key_before = second.gateway_options[:idempotency_key]

      first.destroy!

      # The display number shifts (accepted trade-off); the gateway key must not.
      expect(second.reload.gateway_options[:idempotency_key]).to eq(key_before)
    end
  end
end
