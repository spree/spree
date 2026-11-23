require 'spec_helper'

# A signed delivery, parsed and then run through core's jobs as the webhook
# endpoint enqueues them.
RSpec.describe SpreeAdyen::Gateway, 'webhook settlement' do
  let(:store) { @default_store }
  let(:gateway) { create(:adyen_gateway, :configured, store: store) }
  let(:order) { create(:order_with_line_items, store: store) }
  let(:minor_units) { SpreeAdyen::Amounts.to_adyen(order.total, order.currency) }
  let(:amount) { { 'value' => minor_units, 'currency' => order.currency } }

  before { order.fulfillments.each { |fulfillment| fulfillment.update_column(:status, 'ready') } if order.respond_to?(:fulfillments) }

  def deliver(name, received_at: Time.current, **overrides)
    result = gateway.parse_webhook_event(
      adyen_webhook(name, merchantAccountCode: gateway.preferred_merchant_account, amount: amount, **overrides), {}
    )
    return if result.nil?

    if result[:payment_session]
      Spree::Payments::HandleWebhookJob.perform_now(
        payment_method_id: gateway.id, action: result[:action].to_s,
        payment_session_id: result[:payment_session].id, metadata: result[:metadata]
      )
    else
      Spree::Payments::HandleModificationWebhookJob.perform_now(
        payment_method_id: gateway.id, action: result[:action].to_s, reference: result[:reference],
        payment_id: result[:payment]&.id, metadata: result[:metadata], received_at: received_at.iso8601
      )
    end
  end

  it 'settles the session from a signed authorisation, with the PSP reference on the payment' do
    session = create(:adyen_payment_session, owner: order, payment_method: gateway, amount: order.total,
                                             external_id: 'CS0000000000SESSION', external_data: { 'manual_capture' => true })

    deliver('authorisation')

    payment = session.reload.payment
    expect(payment).to be_pending
    expect(payment.metadata['adyen_psp_reference']).to eq('PSPAUTH000000001')
  end

  context 'with a payment Phases 9 and 10 left waiting' do
    let!(:payment) { adyen_session_payment(gateway: gateway, order: order, status: 'requested', psp_reference: 'PSPAUTH000000001') }

    it 'completes a requested capture on CAPTURE' do
      capture_event = create(:payment_capture_event, :requested, payment: payment, transaction_id: 'PSPMODIFICATION1', amount: payment.amount)

      deliver('capture')

      expect(capture_event.reload).to be_completed
      expect(payment.reload).to be_completed
    end

    it 'voids the payment on CANCELLATION' do
      deliver('cancellation')

      expect(payment.reload).to be_void
    end

    it 'fails a requested refund on REFUND_FAILED' do
      payment.update_columns(status: 'completed')
      refund = create(:refund, :requested, payment: payment, amount: 1, transaction_id: 'PSPMODIFICATION1')

      deliver('refund_failed', reason: 'Account closed')

      expect(refund.reload).to have_attributes(status: 'failed', failure_reason: 'Account closed')
    end

    it 'waits for a capture event the capture request has not written yet' do
      payment.update_columns(status: 'processing')

      expect { deliver('capture') }.to have_enqueued_job(Spree::Payments::HandleModificationWebhookJob)
      expect(payment.reload).to be_processing

      capture_event = create(:payment_capture_event, :requested, payment: payment, transaction_id: 'PSPMODIFICATION1', amount: payment.amount)
      payment.update_columns(status: 'requested')
      deliver('capture')

      expect(capture_event.reload).to be_completed
      expect(payment.reload).to be_completed
    end

    it 'records a capture whose answer never reached Spree on the payment it left processing' do
      payment.update_columns(status: 'processing')

      deliver('capture', received_at: 10.minutes.ago)

      expect(payment.capture_events.sole).to have_attributes(status: 'completed', transaction_id: 'PSPMODIFICATION1', amount: order.total)
      expect(payment.reload).to be_completed
    end
  end
end
