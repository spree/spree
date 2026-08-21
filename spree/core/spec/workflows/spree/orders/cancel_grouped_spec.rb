require 'spec_helper'

# Cancelling one order of a split checkout must give back that order's money
# and nothing else: the payment is shared, so releasing it wholesale would
# un-pay the sellers still shipping.
RSpec.describe Spree::Orders::Cancel, 'an order placed in a split checkout' do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:group) { create(:order_group, store: store) }

  let!(:seller_order) do
    create(:order, store: store, order_group: group, seller: seller, total: 40, status: 'placed',
                   completed_at: Time.current)
  end
  let!(:first_party_order) do
    create(:order, store: store, order_group: group, total: 60, status: 'placed', completed_at: Time.current)
  end

  let(:payment) do
    create(:payment, order: nil, cart: nil, order_group: group, amount: 100, status: 'completed')
  end

  let!(:seller_split) do
    create(:payment_split, payment: payment, order: seller_order, authorized_amount: 40, captured_amount: 40)
  end
  let!(:first_party_split) do
    create(:payment_split, payment: payment, order: first_party_order, authorized_amount: 60, captured_amount: 60)
  end

  before { payment }

  # The default. An operator cancelling an order is not thereby asking to move
  # money — that is a separate decision, and the plain path already treats it
  # as one.
  context 'without refund_payments' do
    it 'refunds nothing' do
      expect { described_class.call(order: seller_order) }.not_to change { Spree::Refund.count }
    end

    it 'still releases what the order had reserved but never drew' do
      seller_split.update!(captured_amount: 10)

      described_class.call(order: seller_order)

      expect(seller_split.reload.authorized_amount).to eq(10)
    end
  end

  # A parcel reserves what it is about to draw before asking the gateway, so a
  # share can hold a claim while the charge is still in flight. Settling
  # through that would release an authorization about to be drawn, or refund
  # money nobody took — and it must hold even when a sibling's capture has
  # already completed the shared payment.
  context 'while a capture is still in flight' do
    let(:in_flight_payment) do
      create(:payment, order: nil, cart: nil, order_group: group, amount: 40, status: 'completed')
    end
    let!(:claimed_split) do
      create(:payment_split, payment: in_flight_payment, order: seller_order,
                             authorized_amount: 40, claimed_amount: 40)
    end

    before { seller_split.destroy! }

    it 'leaves the claimed share alone rather than releasing it' do
      described_class.call(order: seller_order)

      expect(claimed_split.reload.authorized_amount).to eq(40)
    end

    # The payment reads completed because a *sibling's* capture finished it —
    # which says nothing about whether this share's charge landed.
    it 'holds even when a sibling’s capture completed the shared payment' do
      in_flight_payment.capture_events.create!(amount: 40)

      expect {
        described_class.call(order: seller_order, refund_payments: true)
      }.not_to change { claimed_split.reload.authorized_amount }
    end

    it 'refunds nothing the gateway has not confirmed' do
      expect {
        described_class.call(order: seller_order, refund_payments: true)
      }.not_to change { Spree::Refund.count }
    end
  end

  context 'with refund_payments' do
    it 'gives back what this order was actually paid' do
      described_class.call(order: seller_order, refund_payments: true)

      expect(Spree::Refund.where(order_id: seller_order.id).sum(:amount)).to eq(40)
    end

    it 'leaves the sibling’s money alone' do
      described_class.call(order: seller_order, refund_payments: true)

      expect(Spree::Refund.where(order_id: first_party_order.id)).to be_empty
      expect(first_party_split.reload.captured_amount).to eq(60)
    end

    it 'honours an explicit smaller amount' do
      described_class.call(order: seller_order, refund_payments: true, refund_amount: 15)

      expect(Spree::Refund.where(order_id: seller_order.id).sum(:amount)).to eq(15)
    end
  end
end
