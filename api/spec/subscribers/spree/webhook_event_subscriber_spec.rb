# frozen_string_literal: true

require 'spec_helper'

module Spree
  describe WebhookEventSubscriber do
    let(:store) { create(:store) }
    let!(:webhook_endpoint) { create(:webhook_endpoint, store: store, subscriptions: ['order.created']) }
    let(:event_name) { 'order.created' }
    let(:event_payload) { { id: 1, number: 'R123456' } }
    let(:event_id) { SecureRandom.uuid }
    let(:event_created_at) { Time.current }
    let(:event_metadata) { {} }
    let(:event) { double('Event', id: event_id, name: event_name, payload: event_payload, metadata: event_metadata, created_at: event_created_at) }

    before do
      allow(Spree::Current).to receive(:store).and_return(store)
      allow(Spree::Api::Config).to receive(:webhooks_enabled).and_return(true)
    end

    describe '#handle' do
      context 'when webhooks are enabled' do
        it 'creates a webhook delivery record' do
          expect {
            described_class.new.handle(event)
          }.to change(Spree::WebhookDelivery, :count).by(1)
        end

        it 'queues a webhook delivery job' do
          expect {
            described_class.new.handle(event)
          }.to have_enqueued_job(Spree::WebhookDeliveryJob)
        end

        it 'creates delivery with correct attributes' do
          described_class.new.handle(event)

          delivery = Spree::WebhookDelivery.last
          expect(delivery.event_name).to eq(event_name)
          expect(delivery.url).to eq(webhook_endpoint.url)
          expect(delivery.webhook_endpoint).to eq(webhook_endpoint)

          # Reload to get the updated payload with webhook_delivery_id
          delivery.reload
          expect(delivery.payload).to include(
            'id' => event_id,
            'event' => event_name,
            'webhook_delivery_id' => delivery.id,
            'data' => event_payload.stringify_keys
          )
          expect(delivery.payload['created_at']).to eq(event_created_at.iso8601)
        end
      end

      context 'when webhooks are disabled' do
        before do
          allow(Spree::Api::Config).to receive(:webhooks_enabled).and_return(false)
        end

        it 'does not create a webhook delivery' do
          expect {
            described_class.new.handle(event)
          }.not_to change(Spree::WebhookDelivery, :count)
        end

        it 'does not queue a job' do
          expect {
            described_class.new.handle(event)
          }.not_to have_enqueued_job(Spree::WebhookDeliveryJob)
        end
      end

      context 'when endpoint is not subscribed to event' do
        let(:event_name) { 'product.created' }

        it 'does not create a webhook delivery' do
          expect {
            described_class.new.handle(event)
          }.not_to change(Spree::WebhookDelivery, :count)
        end
      end

      context 'when endpoint is inactive' do
        before { webhook_endpoint.update!(active: false) }

        it 'does not create a webhook delivery' do
          expect {
            described_class.new.handle(event)
          }.not_to change(Spree::WebhookDelivery, :count)
        end
      end

      context 'with multiple endpoints' do
        let!(:second_endpoint) { create(:webhook_endpoint, store: store, subscriptions: ['order.created']) }
        let!(:other_event_endpoint) { create(:webhook_endpoint, store: store, subscriptions: ['product.created']) }

        it 'creates deliveries for all subscribed endpoints' do
          expect {
            described_class.new.handle(event)
          }.to change(Spree::WebhookDelivery, :count).by(2)
        end

        it 'queues jobs for each endpoint' do
          expect {
            described_class.new.handle(event)
          }.to have_enqueued_job(Spree::WebhookDeliveryJob).exactly(:twice)
        end
      end

      context 'with wildcard subscription' do
        let!(:wildcard_endpoint) { create(:webhook_endpoint, :all_events, store: store) }

        it 'creates delivery for any event' do
          random_event = double('Event', id: SecureRandom.uuid, name: 'random.event', payload: {}, metadata: event_metadata, created_at: event_created_at)

          expect {
            described_class.new.handle(random_event)
          }.to change(wildcard_endpoint.webhook_deliveries, :count).by(1)
        end
      end

      context 'with pattern subscription' do
        let!(:pattern_endpoint) { create(:webhook_endpoint, store: store, subscriptions: ['order.*']) }
        let(:event_name) { 'order.completed' }

        it 'creates delivery for matching pattern events' do
          expect {
            described_class.new.handle(event)
          }.to change(pattern_endpoint.webhook_deliveries, :count).by(1)
        end
      end

      context 'when an error occurs' do
        before do
          allow(Spree::WebhookEndpoint).to receive(:active).and_raise(StandardError, 'Database error')
          allow(Rails.logger).to receive(:error)
          allow(Rails.error).to receive(:report)
        end

        it 'logs the error' do
          described_class.new.handle(event)

          expect(Rails.logger).to have_received(:error).with(/Error processing event/)
        end

        it 'reports error to Rails.error' do
          described_class.new.handle(event)

          expect(Rails.error).to have_received(:report).with(an_instance_of(StandardError))
        end

        it 'does not raise the error' do
          expect {
            described_class.new.handle(event)
          }.not_to raise_error
        end
      end
    end
  end
end
