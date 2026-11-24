require 'spec_helper'

RSpec.describe Spree::StoreCreditRefundSubscriber do
  let(:order) { create(:completed_order_with_totals) }
  let!(:payment) { create(:payment, order: order, amount: order.total, status: 'completed') }
  let!(:credit) { give_back_as_store_credit(order, 10) }

  def deliver(record)
    described_class.new.handle(
      Spree::Event.new(name: 'store_credit.deleted', payload: { 'id' => record.prefixed_id }, store_id: order.store_id)
    )
  end

  it 'fails the refunds of a withdrawn credit, so the payment can give the money back again' do
    credit.destroy!

    deliver(credit)

    refund = credit.refunds.sole
    expect(refund.reload).to be_failed
    expect(refund.failure_reason).to eq(I18n.t('spree.store_credit_withdrawn'))
    expect(payment.reload.credit_allowed).to eq(payment.amount)
  end

  it 'leaves the refunds of a credit that still stands' do
    deliver(credit)

    expect(credit.refunds.sole.reload).to be_completed
  end
end
