require 'spec_helper'

# Refunding one seller's order in a split checkout must leave its siblings
# alone: the customer's money comes back out of the one charge either way, but
# what each seller is owed does not move because a neighbour refunded.
RSpec.describe Spree::PaymentSplitSubscriber, :events, type: :model do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:group) { create(:order_group, store: store) }

  let!(:seller_order) { create(:order, store: store, order_group: group, seller: seller, total: 40) }
  let!(:first_party_order) { create(:order, store: store, order_group: group, total: 60) }

  let(:payment) do
    create(:payment, order: nil, cart: nil, order_group: group, amount: 100, status: 'completed')
  end

  let!(:seller_split) do
    create(:payment_split, payment: payment, order: seller_order,
                           authorized_amount: 40, captured_amount: 40)
  end
  let!(:first_party_split) do
    create(:payment_split, payment: payment, order: first_party_order,
                           authorized_amount: 60, captured_amount: 60)
  end

  def refund!(order, amount)
    create(:refund, payment: payment, order: order, amount: amount)
  end

  it 'records the refund against only that order’s share' do
    refund!(seller_order, 15)

    expect(seller_split.reload.refunded_amount).to eq(15)
    expect(first_party_split.reload.refunded_amount).to eq(0)
  end

  it 'reports the refunded order as refunded and leaves the sibling’s share alone' do
    Spree::Orders::UpdateStatuses.call(order: first_party_order)

    refund!(seller_order, 40)

    expect(seller_order.reload.payment_status).to eq('refunded')
    expect(first_party_order.reload.payment_status).to eq('paid')
    expect(first_party_split.reload.refunded_amount).to eq(0)
  end

  it 'reports a part refund as partially refunded' do
    refund!(seller_order, 10)

    expect(seller_order.reload.payment_status).to eq('partially_refunded')
  end

  it 'totals several refunds on one order rather than counting the last' do
    refund!(seller_order, 10)
    refund!(seller_order, 5)

    expect(seller_split.reload.refunded_amount).to eq(15)
  end

  # order.paid is public webhook API, and it is published from the payment's
  # own after_commit — which runs before the subscriber marks the shares
  # captured, so the figure it reads has to count this payment's share itself.
  it 'declares each child paid when the shared payment settles' do
    pending_payment = create(:payment, order: nil, cart: nil, order_group: group,
                                       amount: 100, status: 'pending')
    create(:payment_split, payment: pending_payment, order: seller_order, authorized_amount: 40)
    create(:payment_split, payment: pending_payment, order: first_party_order, authorized_amount: 60)
    seller_split.destroy!
    first_party_split.destroy!

    published = []
    allow(Spree::Events).to receive(:publish).and_wrap_original do |original, name, *rest|
      published << name
      original.call(name, *rest)
    end

    pending_payment.complete!

    expect(published.count { |name| name == 'order.paid' }).to eq(2)
  end

  it 'leaves an ungrouped order alone' do
    plain_order = create(:order, store: store, total: 20)
    plain_payment = create(:payment, order: plain_order, amount: 20, status: 'completed')

    expect { create(:refund, payment: plain_payment, amount: 5) }.not_to raise_error
  end
end
