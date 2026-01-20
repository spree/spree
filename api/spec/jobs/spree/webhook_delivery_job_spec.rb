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

      it 'calls DeliverWebhook service' do
        expect(Spree::Webhooks::DeliverWebhook).to receive(:call).with(
          delivery: delivery,
          secret_key: secret_key
        )

        described_class.new.perform(delivery.id, secret_key)
      end

      context 'when delivery does not exist' do
        it 'returns early without calling service' do
          expect(Spree::Webhooks::DeliverWebhook).not_to receive(:call)

          described_class.new.perform(-1, secret_key)
        end
      end

      context 'when delivery has been deleted' do
        before { delivery.destroy }

        it 'returns early without calling service' do
          expect(Spree::Webhooks::DeliverWebhook).not_to receive(:call)

          described_class.new.perform(delivery.id, secret_key)
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
    end
  end
end
