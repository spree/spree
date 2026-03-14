require 'spec_helper'

RSpec.describe Spree::Payments::HandleWebhookJob, type: :job do
  let(:store) { @default_store }
  let(:order) { create(:order_with_line_items, store: store) }
  let(:payment_method) { create(:bogus_payment_method, stores: [store]) }
  let(:payment_session) { create(:bogus_payment_session, order: order, payment_method: payment_method, amount: order.total) }

  before do
    order.update_column(:state, 'payment')
    order.shipments.each { |s| s.update_column(:state, 'ready') }
  end

  describe '#perform' do
    it 'calls the HandleWebhook service with correct arguments' do
      expect(Spree::Payments::HandleWebhook).to receive(:call).with(
        payment_method: payment_method,
        action: :captured,
        payment_session: payment_session
      )

      described_class.new.perform(
        payment_method_id: payment_method.id,
        action: 'captured',
        payment_session_id: payment_session.id
      )
    end

    it 'converts action string to symbol' do
      expect(Spree::Payments::HandleWebhook).to receive(:call).with(
        hash_including(action: :authorized)
      )

      described_class.new.perform(
        payment_method_id: payment_method.id,
        action: 'authorized',
        payment_session_id: payment_session.id
      )
    end
  end

  describe 'queue' do
    it 'uses the payment_webhooks queue' do
      expect(described_class.new.queue_name).to eq(Spree.queues.payment_webhooks.to_s)
    end
  end

  describe 'error handling' do
    it 'discards on ActiveRecord::RecordNotFound' do
      expect {
        described_class.perform_now(
          payment_method_id: 0,
          action: 'captured',
          payment_session_id: payment_session.id
        )
      }.not_to raise_error
    end

    it 'retries on ActiveRecord::Deadlocked' do
      expect(described_class.rescue_handlers).to include(
        have_attributes(first: 'ActiveRecord::Deadlocked')
      )
    end

    it 'retries on ActiveRecord::LockWaitTimeout' do
      expect(described_class.rescue_handlers).to include(
        have_attributes(first: 'ActiveRecord::LockWaitTimeout')
      )
    end
  end

  describe 'enqueuing' do
    it 'can be enqueued with perform_later' do
      expect {
        described_class.perform_later(
          payment_method_id: payment_method.id,
          action: 'captured',
          payment_session_id: payment_session.id
        )
      }.to have_enqueued_job(described_class)
    end
  end
end
