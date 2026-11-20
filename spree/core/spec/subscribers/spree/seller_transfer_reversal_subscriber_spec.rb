require 'spec_helper'

RSpec.describe Spree::SellerTransferReversalSubscriber do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:order) { create(:order, store: store, seller: seller, total: 100) }
  let(:payment) { create(:payment, order: order, amount: 100, status: 'completed') }
  let(:workflow) { double(call: nil) }

  before { allow(Spree).to receive(:seller_transfer_reverse_workflow).and_return(workflow) }

  def deliver(name, record, metadata = {})
    described_class.new.handle(
      Spree::Event.new(name: name, payload: { 'id' => record.prefixed_id }, metadata: metadata, store_id: store.id)
    )
  end

  it "reverses the seller's earning for a refund created completed" do
    refund = create(:refund, payment: payment, amount: 10)

    deliver('refund.created', refund)

    expect(workflow).to have_received(:call).with(order: order, amount: refund.amount, refund: refund)
  end

  it 'waits for a refund the provider has not answered yet' do
    refund = create(:refund, :requested, payment: payment, amount: 10)

    deliver('refund.created', refund)

    expect(workflow).not_to have_received(:call)
  end

  it 'reverses the refund the payment.refunded event names, once it completed' do
    completed = create(:refund, payment: payment, amount: 10)

    deliver('payment.refunded', payment, refund_id: completed.prefixed_id)

    expect(workflow).to have_received(:call).once.with(order: order, amount: completed.amount, refund: completed)
  end

  # A refund made before the order shipped reversed nothing then, and must not
  # be reversed later because another refund completed.
  it "leaves the payment's other refunds alone" do
    create(:refund, payment: payment, amount: 5)
    latest = create(:refund, payment: payment, amount: 10)

    deliver('payment.refunded', payment, refund_id: latest.prefixed_id)

    expect(workflow).to have_received(:call).once.with(order: order, amount: latest.amount, refund: latest)
  end
end
