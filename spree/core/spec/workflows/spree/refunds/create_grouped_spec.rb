require 'spec_helper'

# A payment shared by a split checkout holds several orders' money, so what one
# of them may take back is bounded by its own share — not by the payment's
# balance, which says nothing about whose money is left in it.
RSpec.describe Spree::Refunds::Create, 'against a shared payment' do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:group) { create(:order_group, store: store) }

  let!(:seller_order) { create(:order, store: store, order_group: group, seller: seller, total: 40) }
  let!(:first_party_order) { create(:order, store: store, order_group: group, total: 60) }

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

  it 'refunds up to the order’s own share' do
    result = described_class.call(payment: payment, amount: 40, order: seller_order)

    expect(result).to be_success
    expect(result.value.amount).to eq(40)
  end

  it 'refuses to spend a sibling’s money, even though the payment holds it' do
    result = described_class.call(payment: payment, amount: 70, order: seller_order)

    expect(result).to be_failure
    expect(payment.reload.refunds).to be_empty
  end

  it 'refuses once the order’s share is already refunded' do
    described_class.call(payment: payment, amount: 40, order: seller_order)
    seller_split.reload

    result = described_class.call(payment: payment, amount: 5, order: seller_order)

    expect(result).to be_failure
  end

  # Nothing can fill this in afterwards: a shared payment cannot say which of
  # its orders is being put right, so a refund without one would credit the
  # gateway while no child's totals or share moved.
  it 'refuses a refund that names no order' do
    result = described_class.call(payment: payment, amount: 10)

    expect(result).to be_failure
    expect(payment.reload.refunds).to be_empty
  end

  it 'stamps the refund with the order it put right' do
    refund = described_class.call(payment: payment, amount: 10, order: seller_order).value

    expect(refund.order).to eq(seller_order)
  end
end
