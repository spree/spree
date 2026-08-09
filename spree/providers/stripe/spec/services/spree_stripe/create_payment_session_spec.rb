require 'spec_helper'

RSpec.describe SpreeStripe::CreatePaymentSession do
  subject(:session) { described_class.new.call(order, gateway) }

  let(:store) { @default_store }
  let(:gateway) { create(:stripe_gateway, store: store) }
  let(:order) { create(:order_with_line_items, store: store) }

  context 'when store credits cover the whole order (zero amount)' do
    before { allow(order).to receive(:total_minus_store_credits).and_return(0) }

    it 'skips Stripe and returns nil' do
      expect(gateway).not_to receive(:create_payment_session)
      expect(gateway).not_to receive(:update_payment_session)
      expect(session).to be_nil
    end
  end

  context 'when no pending session exists' do
    it 'creates one for the order' do
      new_session = instance_double(Spree::PaymentSessions::Stripe)
      expect(gateway).to receive(:create_payment_session).with(order: order).and_return(new_session)
      expect(session).to eq(new_session)
    end
  end

  context 'when a pending session exists with the current amount' do
    let!(:existing) do
      create(:stripe_payment_session, owner: order, payment_method: gateway, amount: order.total_minus_store_credits)
    end

    it 'reuses it without creating or updating' do
      expect(gateway).not_to receive(:create_payment_session)
      expect(gateway).not_to receive(:update_payment_session)
      expect(session).to eq(existing)
    end
  end

  context 'when a pending session exists with a stale amount' do
    let!(:existing) do
      create(:stripe_payment_session, owner: order, payment_method: gateway, amount: 1)
    end

    it 'syncs the amount before reusing it' do
      expect(gateway).to receive(:update_payment_session).
        with(payment_session: existing, amount: order.total_minus_store_credits)
      expect(session).to eq(existing)
    end
  end
end
