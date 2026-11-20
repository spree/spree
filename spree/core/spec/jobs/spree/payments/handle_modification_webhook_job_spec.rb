require 'spec_helper'

RSpec.describe Spree::Payments::HandleModificationWebhookJob, type: :job do
  let(:payment_method) { create(:credit_card_payment_method, preferred_requested_mode: true) }
  let(:payment) { create(:payment, payment_method: payment_method, status: 'requested', response_code: 'BGS-PAY') }
  let(:refund) do
    create(:refund, :requested, amount: 10, transaction_id: 'BGS-refund-1',
                                payment: create(:payment, payment_method: payment_method, status: 'completed'))
  end

  def perform(received_at: Time.current, **overrides)
    job = described_class.new
    allow(job).to receive(:retry_job)
    job.perform(
      payment_method_id: payment_method.id, action: 'void_succeeded', reference: 'BGS-PAY',
      received_at: received_at.iso8601, **overrides
    )
    job
  end

  it 'hands the record the reference names, the action and the metadata to the workflow' do
    expect(Spree::Payments::HandleModificationWebhook).to receive(:call).with(
      payment_method: payment_method, action: :refund_failed, record: refund, metadata: { 'reason' => 'Refused' }
    ).and_return(Spree::ServiceModule::Result.new(true, refund, nil))

    perform(action: 'refund_failed', reference: 'BGS-refund-1', metadata: { 'reason' => 'Refused' })
  end

  it 'raises so it is retried when the workflow fails' do
    payment
    allow(Spree::Payments::HandleModificationWebhook).to receive(:call).
      and_return(Spree::ServiceModule::Result.new(false, payment, 'lock timeout'))

    expect { perform }.to raise_error(described_class::OutcomeFailed, /lock timeout/)
  end

  describe 'an outcome whose record is not written yet' do
    it 'looks again soon, then less often' do
      expect(Spree::Payments::HandleModificationWebhook).not_to receive(:call)

      expect(perform(reference: 'BGS-UNKNOWN')).to have_received(:retry_job).with(wait: 5.seconds)

      later = described_class.new
      later.executions = 10
      allow(later).to receive(:retry_job)
      later.perform(payment_method_id: payment_method.id, action: 'refund_succeeded', reference: 'BGS-UNKNOWN',
                    received_at: 3.days.ago.iso8601)
      expect(later).to have_received(:retry_job).with(wait: 6.hours)
    end

    it 'settles it once a retried request writes the record' do
      expect(perform(action: 'refund_succeeded', reference: 'BGS-refund-2')).to have_received(:retry_job)

      refund.update_columns(transaction_id: 'BGS-refund-2')
      perform(action: 'refund_succeeded', reference: 'BGS-refund-2')

      expect(refund.reload).to be_completed
    end

    it 'reports it once a retried request could no longer get the first answer' do
      allow(Rails.error).to receive(:report)

      job = perform(action: 'refund_succeeded', reference: 'BGS-UNKNOWN', received_at: 8.days.ago)

      expect(job).not_to have_received(:retry_job)
      expect(Rails.error).to have_received(:report).
        with(kind_of(described_class::RecordNeverWritten), hash_including(handled: true))
    end

    it "never reads another method's records" do
      create(:payment, status: 'requested', response_code: 'BGS-OTHER')

      expect(perform(reference: 'BGS-OTHER')).to have_received(:retry_job)
    end
  end

  describe 'a capture whose answer never reached Spree' do
    let(:payment) { create(:payment, payment_method: payment_method, status: 'processing', response_code: 'BGS-PAY', amount: 50) }

    def capture_outcome(received_at:, action: 'capture_succeeded')
      perform(action: action, reference: 'BGS-capture-9', payment_id: payment.id,
              metadata: { 'amount' => '30.0' }, received_at: received_at)
    end

    it 'waits while the request may still be running' do
      expect(capture_outcome(received_at: 1.minute.ago)).to have_received(:retry_job)
      expect(payment.capture_events).to be_empty
    end

    it 'records the capture the provider confirmed on the payment the request left processing' do
      capture_outcome(received_at: 10.minutes.ago)

      expect(payment.capture_events.sole).to have_attributes(amount: 30, status: 'completed', transaction_id: 'BGS-capture-9')
      expect(payment.reload).to be_completed
    end

    it 'fails the payment when the provider reports the capture failed' do
      capture_outcome(received_at: 10.minutes.ago, action: 'capture_failed')

      expect(payment.capture_events.sole).to be_failed
      expect(payment.reload).to be_failed
    end

    it 'leaves a payment that is no longer processing alone' do
      payment.update_columns(status: 'pending')

      expect(capture_outcome(received_at: 10.minutes.ago)).to have_received(:retry_job)
      expect(payment.capture_events).to be_empty
    end
  end

  it 'discards an outcome for a payment method that no longer exists' do
    expect {
      described_class.perform_now(payment_method_id: 0, action: 'void_succeeded', reference: 'BGS-PAY', received_at: Time.current.iso8601)
    }.not_to raise_error
  end

  it 'retries the way the session webhook job does' do
    expect(described_class.rescue_handlers.map(&:first)).to include(
      'ActiveRecord::Deadlocked', 'ActiveRecord::LockWaitTimeout', described_class::OutcomeFailed.name
    )
  end

  it 'uses the payment_webhooks queue' do
    expect(described_class.new.queue_name).to eq(Spree.queues.payment_webhooks.to_s)
  end
end
