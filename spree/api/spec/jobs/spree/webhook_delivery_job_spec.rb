# frozen_string_literal: true

require 'spec_helper'

module Spree
  describe WebhookDeliveryJob, type: :job do
    let(:store) { @default_store }
    let(:webhook_endpoint) { create(:webhook_endpoint, store: store) }
    let(:delivery) { create(:webhook_delivery, :pending, webhook_endpoint: webhook_endpoint) }
    let(:secret_key) { webhook_endpoint.secret_key }

    describe '#perform' do
      before do
        stub_request(:post, delivery.url).to_return(status: 200, body: '{}')
      end

      it 'calls DeliverWebhook service with secret_key from endpoint' do
        expect(Spree::Webhooks::DeliverWebhook).to receive(:call).with(
          delivery: delivery,
          secret_key: secret_key
        )

        described_class.new.perform(delivery.id)
      end

      context 'when delivery does not exist' do
        it 'returns early without calling service' do
          expect(Spree::Webhooks::DeliverWebhook).not_to receive(:call)

          described_class.new.perform(-1)
        end
      end

      context 'when delivery has been deleted' do
        before { delivery.destroy }

        it 'returns early without calling service' do
          expect(Spree::Webhooks::DeliverWebhook).not_to receive(:call)

          described_class.new.perform(delivery.id)
        end
      end
    end

    describe 'queue' do
      it 'uses the webhooks queue' do
        expect(described_class.new.queue_name).to eq(Spree.queues.webhooks.to_s)
      end
    end

    describe 'retry behavior' do
      it 'has retry_on configured' do
        # Verify the job class has retry behavior configured
        expect(described_class.ancestors).to include(ActiveJob::Exceptions)
      end

      # ActiveJob handler lookup is reverse-declaration-order. Because this job
      # declares `retry_on StandardError` and `ActiveJob::DeserializationError < StandardError`,
      # the parent's `discard_on ActiveJob::DeserializationError` would be shadowed
      # if this job didn't re-declare the discard *after* the retry. Without that
      # re-declaration, a deserialization failure would retry forever.
      it 'discards DeserializationError instead of retrying' do
        last_matching = described_class.rescue_handlers.reverse_each.detect do |class_or_name, _|
          rescued = class_or_name.is_a?(String) ? class_or_name.constantize : class_or_name
          rescued >= ActiveJob::DeserializationError
        end
        expect(last_matching&.first.to_s).to eq('ActiveJob::DeserializationError')
      end
    end
  end
end
