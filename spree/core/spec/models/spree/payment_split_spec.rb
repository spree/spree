require 'spec_helper'

RSpec.describe Spree::PaymentSplit, type: :model do
  let(:store) { @default_store }
  let(:group) { create(:order_group, store: store) }
  # The order exists before the payment: a payment is sized against what it is
  # paying for, and an empty group is worth nothing.
  let!(:order) { create(:order, store: store, order_group: group, total: 60) }
  let(:payment) { create(:payment, order: nil, cart: nil, order_group: group, amount: 40) }

  describe 'one share per order and payment' do
    it 'refuses a second share for the same pair' do
      create(:payment_split, payment: payment, order: order)
      duplicate = build(:payment_split, payment: payment, order: order)

      expect(duplicate).not_to be_valid
    end

    it 'allows the same order a share of a second payment' do
      create(:payment_split, payment: payment, order: order)
      other_payment = create(:payment, order: nil, cart: nil, order_group: group, amount: 10)

      expect(build(:payment_split, payment: other_payment, order: order)).to be_valid
    end
  end

  describe '#refundable_amount' do
    let(:payment) { create(:payment, order: nil, cart: nil, order_group: group, amount: 40, status: 'completed') }

    it 'reserves a requested refund and releases a failed one' do
      split = create(:payment_split, payment: payment, order: order, authorized_amount: 40, captured_amount: 40)
      create(:refund, :requested, payment: payment, order: order, amount: 10)
      create(:refund, :failed, payment: payment, order: order, amount: 5)

      expect(split.refundable_amount).to eq(30)
    end
  end

  describe '#net_captured_amount' do
    it 'is what is left after refunds' do
      split = create(:payment_split, payment: payment, order: order, captured_amount: 20, refunded_amount: 5)

      expect(split.net_captured_amount).to eq(15)
    end
  end
end
