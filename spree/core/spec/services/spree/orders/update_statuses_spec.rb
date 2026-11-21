require 'spec_helper'

RSpec.describe Spree::Orders::UpdateStatuses do
  let(:store) { @default_store }

  describe 'payment status' do
    let(:order) { create(:completed_order_with_totals, store: store) }

    it 'rolls up an order whose only payment waits on its provider as authorized' do
      create(:payment, order: order, amount: order.total, status: 'requested')

      described_class.call(order: order)

      expect(order.reload.payment_status).to eq('authorized')
    end

    it 'counts no refund the provider has not completed' do
      payment = create(:payment, order: order, amount: order.total, status: 'completed')
      create(:refund, :requested, payment: payment, amount: 5)
      create(:refund, :failed, payment: payment, amount: 5)

      described_class.call(order: order)

      expect(order.reload.payment_status).to eq('paid')
    end

    it 'gives the same figures for rows written by a gateway that answers at once' do
      payment = create(:payment, order: order, amount: order.total, status: 'completed')
      create(:refund, payment: payment, amount: 5)

      described_class.call(order: order)

      expect(order.reload.payment_status).to eq('partially_refunded')
    end
  end

  # A split checkout's child reads its shares: a capture the provider has not
  # answered keeps its claim and leaves the share authorized.
  describe 'payment status of a split checkout child' do
    let(:group) { create(:order_group, store: store) }
    let!(:child) { create(:order, store: store, order_group: group, total: 40) }
    let(:payment) { create(:payment, order: nil, cart: nil, order_group: group, amount: 40, status: 'requested') }

    it 'rolls up a share waiting on its provider as authorized' do
      create(:payment_split, payment: payment, order: child, authorized_amount: 40, claimed_amount: 40)

      described_class.call(order: child)

      expect(child.reload.payment_status).to eq('authorized')
    end
  end
end
