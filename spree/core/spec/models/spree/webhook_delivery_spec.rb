# frozen_string_literal: true

require 'spec_helper'

describe Spree::WebhookDelivery, type: :model do
  let(:store) { @default_store }
  let(:webhook_endpoint) { create(:webhook_endpoint, store: store) }
  let(:webhook_delivery) { build(:webhook_delivery, webhook_endpoint: webhook_endpoint) }

  describe 'scopes' do
    let!(:pending_delivery) { create(:webhook_delivery, :pending, webhook_endpoint: webhook_endpoint) }
    let!(:successful_delivery) { create(:webhook_delivery, :successful, webhook_endpoint: webhook_endpoint) }
    let!(:failed_delivery) { create(:webhook_delivery, :failed, webhook_endpoint: webhook_endpoint) }

    describe '.successful' do
      it 'returns only successful deliveries' do
        expect(described_class.successful).to include(successful_delivery)
        expect(described_class.successful).not_to include(failed_delivery)
        expect(described_class.successful).not_to include(pending_delivery)
      end
    end

    describe '.failed' do
      it 'returns only failed deliveries' do
        expect(described_class.failed).to include(failed_delivery)
        expect(described_class.failed).not_to include(successful_delivery)
        expect(described_class.failed).not_to include(pending_delivery)
      end
    end

    describe '.pending' do
      it 'returns only pending deliveries' do
        expect(described_class.pending).to include(pending_delivery)
        expect(described_class.pending).not_to include(successful_delivery)
        expect(described_class.pending).not_to include(failed_delivery)
      end
    end

    describe '.recent' do
      it 'orders by created_at desc' do
        expect(described_class.recent.first).to eq(failed_delivery)
      end
    end

    describe '.for_event' do
      let!(:order_delivery) { create(:webhook_delivery, webhook_endpoint: webhook_endpoint, event_name: 'order.created') }
      let!(:product_delivery) { create(:webhook_delivery, webhook_endpoint: webhook_endpoint, event_name: 'product.created') }

      it 'returns deliveries for the specified event' do
        expect(described_class.for_event('order.created')).to include(order_delivery)
        expect(described_class.for_event('order.created')).not_to include(product_delivery)
      end
    end
  end

  describe '#successful?' do
    it 'returns true when success is true' do
      delivery = build(:webhook_delivery, :successful)
      expect(delivery.successful?).to be true
    end

    it 'returns false when success is false' do
      delivery = build(:webhook_delivery, :failed)
      expect(delivery.successful?).to be false
    end

    it 'returns false when success is nil' do
      delivery = build(:webhook_delivery, :pending)
      expect(delivery.successful?).to be false
    end
  end

  describe '#failed?' do
    it 'returns true when success is false' do
      delivery = build(:webhook_delivery, :failed)
      expect(delivery.failed?).to be true
    end

    it 'returns false when success is true' do
      delivery = build(:webhook_delivery, :successful)
      expect(delivery.failed?).to be false
    end

    it 'returns false when success is nil' do
      delivery = build(:webhook_delivery, :pending)
      expect(delivery.failed?).to be false
    end
  end

  describe '#pending?' do
    it 'returns true when delivered_at is nil' do
      delivery = build(:webhook_delivery, :pending)
      expect(delivery.pending?).to be true
    end

    it 'returns false when delivered_at is present' do
      delivery = build(:webhook_delivery, :successful)
      expect(delivery.pending?).to be false
    end
  end

  describe '#complete!' do
    let(:delivery) { create(:webhook_delivery, :pending, webhook_endpoint: webhook_endpoint) }

    context 'with successful HTTP response' do
      it 'marks the delivery as successful' do
        delivery.complete!(
          response_code: 200,
          execution_time: 150,
          response_body: '{"status":"ok"}'
        )

        expect(delivery.response_code).to eq(200)
        expect(delivery.execution_time).to eq(150)
        expect(delivery.response_body).to eq('{"status":"ok"}')
        expect(delivery.success).to be true
        expect(delivery.delivered_at).to be_present
        expect(delivery.error_type).to be_nil
        expect(delivery.request_errors).to be_nil
      end

      it 'marks 201 as successful' do
        delivery.complete!(response_code: 201, execution_time: 100)
        expect(delivery.success).to be true
      end

      it 'marks 204 as successful' do
        delivery.complete!(response_code: 204, execution_time: 100)
        expect(delivery.success).to be true
      end
    end

    context 'with failed HTTP response' do
      it 'marks the delivery as failed for 4xx responses' do
        delivery.complete!(
          response_code: 404,
          execution_time: 200,
          response_body: 'Not Found'
        )

        expect(delivery.response_code).to eq(404)
        expect(delivery.success).to be false
        expect(delivery.delivered_at).to be_present
      end

      it 'marks the delivery as failed for 5xx responses' do
        delivery.complete!(
          response_code: 500,
          execution_time: 200,
          response_body: 'Internal Server Error'
        )

        expect(delivery.response_code).to eq(500)
        expect(delivery.success).to be false
      end
    end

    context 'with timeout error' do
      it 'records the timeout error' do
        delivery.complete!(
          execution_time: 30_000,
          error_type: 'timeout',
          request_errors: 'execution expired'
        )

        expect(delivery.response_code).to be_nil
        expect(delivery.error_type).to eq('timeout')
        expect(delivery.request_errors).to eq('execution expired')
        expect(delivery.success).to be false
        expect(delivery.delivered_at).to be_present
      end
    end

    context 'with connection error' do
      it 'records the connection error' do
        delivery.complete!(
          execution_time: 100,
          error_type: 'connection_error',
          request_errors: 'Connection refused'
        )

        expect(delivery.response_code).to be_nil
        expect(delivery.error_type).to eq('connection_error')
        expect(delivery.request_errors).to eq('Connection refused')
        expect(delivery.success).to be false
        expect(delivery.delivered_at).to be_present
      end
    end

    context 'auto-disable on failure' do
      it 'triggers check_auto_disable! on the endpoint after failure' do
        expect(webhook_endpoint).to receive(:check_auto_disable!)

        delivery.complete!(
          response_code: 500,
          execution_time: 100
        )
      end

      it 'does not trigger check_auto_disable! on success' do
        expect(webhook_endpoint).not_to receive(:check_auto_disable!)

        delivery.complete!(
          response_code: 200,
          execution_time: 100
        )
      end
    end
  end

  describe '#redeliver!' do
    let(:delivery) { create(:webhook_delivery, :failed, webhook_endpoint: webhook_endpoint, event_name: 'order.completed', payload: { id: 'test', name: 'order.completed' }) }

    before do
      allow_any_instance_of(Spree::WebhookDelivery).to receive(:queue_for_delivery!)
    end

    it 'creates a new delivery with the same payload and event name' do
      new_delivery = delivery.redeliver!

      expect(new_delivery).to be_persisted
      expect(new_delivery.id).not_to eq(delivery.id)
      expect(new_delivery.event_name).to eq(delivery.event_name)
      expect(new_delivery.payload).to eq(delivery.payload)
      expect(new_delivery.webhook_endpoint).to eq(delivery.webhook_endpoint)
    end

    it 'queues the new delivery' do
      expect_any_instance_of(Spree::WebhookDelivery).to receive(:queue_for_delivery!)
      delivery.redeliver!
    end

    it 'sets event_id to nil on the new delivery' do
      new_delivery = delivery.redeliver!
      expect(new_delivery.event_id).to be_nil
    end
  end
end
