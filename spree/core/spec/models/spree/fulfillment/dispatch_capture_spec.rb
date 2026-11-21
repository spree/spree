require 'spec_helper'

# Dispatch captures only pending payments, so a payment waiting on its
# provider's answer is never captured a second time.
RSpec.describe Spree::Fulfillment, 'capture on dispatch' do
  let(:store) { @default_store }
  let(:order) { create(:order, store: store, total: 50) }
  let(:payment_method) { create(:check_payment_method, store: store, capture_method: 'on_dispatch') }
  let!(:payment) { create(:payment, order: order, amount: 50, status: status, payment_method: payment_method) }

  def dispatch
    fulfillment = create(:fulfillment, order: order, cart: nil)
    allow(fulfillment).to receive(:final_price_with_items).and_return(BigDecimal(50))
    fulfillment.send(:process_order_payments)
  end

  context 'with a payment waiting on its provider' do
    let(:status) { 'requested' }

    it 'passes it by' do
      expect(Spree.payment_capture_workflow).not_to receive(:call)

      dispatch

      expect(payment.reload).to be_requested
    end
  end

  context 'with a pending payment' do
    let(:status) { 'pending' }

    it 'captures it' do
      dispatch

      expect(payment.reload).to be_completed
    end
  end
end
