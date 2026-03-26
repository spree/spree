# frozen_string_literal: true

require 'spec_helper'

describe Spree::WebhookEndpoint, type: :model do
  let(:store) { @default_store }
  let(:webhook_endpoint) { build(:webhook_endpoint, store: store) }

  describe 'validations' do
    describe 'url format' do
      it 'accepts valid https urls' do
        webhook_endpoint.url = 'https://example.com/webhooks'
        expect(webhook_endpoint).to be_valid
      end

      it 'accepts valid http urls' do
        webhook_endpoint.url = 'http://example.com/webhooks'
        expect(webhook_endpoint).to be_valid
      end

      it 'rejects invalid urls' do
        webhook_endpoint.url = 'not-a-url'
        expect(webhook_endpoint).not_to be_valid
        expect(webhook_endpoint.errors[:url]).to be_present
      end

      it 'rejects ftp urls' do
        webhook_endpoint.url = 'ftp://example.com/webhooks'
        expect(webhook_endpoint).not_to be_valid
      end

      it 'rejects urls resolving to private IPs' do
        allow(Resolv).to receive(:getaddresses).with('internal.example.com').and_return(['127.0.0.1'])
        webhook_endpoint.url = 'https://internal.example.com/webhooks'
        expect(webhook_endpoint).not_to be_valid
        expect(webhook_endpoint.errors[:url]).to include('must not point to an internal or private network address')
      end
    end

    describe 'active inclusion' do
      it 'accepts true' do
        webhook_endpoint.active = true
        expect(webhook_endpoint).to be_valid
      end

      it 'accepts false' do
        webhook_endpoint.active = false
        expect(webhook_endpoint).to be_valid
      end

      it 'rejects nil' do
        webhook_endpoint.active = nil
        expect(webhook_endpoint).not_to be_valid
      end
    end
  end

  describe 'callbacks' do
    describe 'before_create :generate_secret_key' do
      it 'generates a secret key on create' do
        endpoint = build(:webhook_endpoint, store: store, secret_key: nil)
        endpoint.save!
        expect(endpoint.secret_key).to be_present
        expect(endpoint.secret_key.length).to eq(64)
      end

      it 'does not overwrite existing secret key' do
        endpoint = build(:webhook_endpoint, store: store, secret_key: 'existing_key')
        endpoint.save!
        expect(endpoint.secret_key).to eq('existing_key')
      end
    end
  end

  describe '#subscribed_to?' do
    context 'with empty subscriptions' do
      let(:endpoint) { build(:webhook_endpoint, subscriptions: []) }

      it 'returns true for any event' do
        expect(endpoint.subscribed_to?('order.created')).to be true
        expect(endpoint.subscribed_to?('product.updated')).to be true
      end
    end

    context 'with wildcard subscription' do
      let(:endpoint) { build(:webhook_endpoint, subscriptions: ['*']) }

      it 'returns true for any event' do
        expect(endpoint.subscribed_to?('order.created')).to be true
        expect(endpoint.subscribed_to?('product.updated')).to be true
      end
    end

    context 'with specific subscriptions' do
      let(:endpoint) { build(:webhook_endpoint, subscriptions: %w[order.created order.completed]) }

      it 'returns true for subscribed events' do
        expect(endpoint.subscribed_to?('order.created')).to be true
        expect(endpoint.subscribed_to?('order.completed')).to be true
      end

      it 'returns false for non-subscribed events' do
        expect(endpoint.subscribed_to?('order.updated')).to be false
        expect(endpoint.subscribed_to?('product.created')).to be false
      end
    end

    context 'with pattern subscriptions' do
      let(:endpoint) { build(:webhook_endpoint, subscriptions: ['order.*']) }

      it 'matches events that fit the pattern' do
        expect(endpoint.subscribed_to?('order.created')).to be true
        expect(endpoint.subscribed_to?('order.completed')).to be true
        expect(endpoint.subscribed_to?('order.updated')).to be true
      end

      it 'does not match events outside the pattern' do
        expect(endpoint.subscribed_to?('product.created')).to be false
        expect(endpoint.subscribed_to?('shipment.shipped')).to be false
      end
    end

    context 'with mixed subscriptions' do
      let(:endpoint) { build(:webhook_endpoint, subscriptions: ['order.*', 'product.created']) }

      it 'matches pattern events' do
        expect(endpoint.subscribed_to?('order.created')).to be true
        expect(endpoint.subscribed_to?('order.completed')).to be true
      end

      it 'matches exact events' do
        expect(endpoint.subscribed_to?('product.created')).to be true
      end

      it 'does not match non-subscribed events' do
        expect(endpoint.subscribed_to?('product.updated')).to be false
      end
    end
  end

  describe '#subscribed_events' do
    context 'with empty subscriptions' do
      let(:endpoint) { build(:webhook_endpoint, subscriptions: []) }

      it 'returns wildcard' do
        expect(endpoint.subscribed_events).to eq(['*'])
      end
    end

    context 'with specific subscriptions' do
      let(:endpoint) { build(:webhook_endpoint, subscriptions: %w[order.created order.completed]) }

      it 'returns the subscriptions' do
        expect(endpoint.subscribed_events).to eq(%w[order.created order.completed])
      end
    end
  end

  describe 'scopes' do
    let!(:active_endpoint) { create(:webhook_endpoint, store: store, active: true) }
    let!(:inactive_endpoint) { create(:webhook_endpoint, :inactive, store: store) }
    let!(:disabled_endpoint) { create(:webhook_endpoint, :auto_disabled, store: store) }

    describe '.enabled' do
      it 'returns active endpoints that are not auto-disabled' do
        expect(described_class.enabled).to include(active_endpoint)
        expect(described_class.enabled).not_to include(inactive_endpoint)
        expect(described_class.enabled).not_to include(disabled_endpoint)
      end
    end
  end

  describe '#send_test!' do
    let(:endpoint) { create(:webhook_endpoint, store: store) }

    before do
      allow_any_instance_of(Spree::WebhookDelivery).to receive(:queue_for_delivery!)
    end

    it 'creates a webhook delivery with test event' do
      expect { endpoint.send_test! }.to change(endpoint.webhook_deliveries, :count).by(1)

      delivery = endpoint.webhook_deliveries.last
      expect(delivery.event_name).to eq('webhook.test')
      expect(delivery.payload['name']).to eq('webhook.test')
      expect(delivery.payload['data']['message']).to be_present
    end

    it 'queues the delivery' do
      expect_any_instance_of(Spree::WebhookDelivery).to receive(:queue_for_delivery!)
      endpoint.send_test!
    end

    it 'returns the delivery' do
      delivery = endpoint.send_test!
      expect(delivery).to be_a(Spree::WebhookDelivery)
      expect(delivery).to be_persisted
    end
  end

  describe '#disable!' do
    let(:endpoint) { create(:webhook_endpoint, store: store) }
    let(:mail_message) { double('Mail', deliver_later: true) }

    before do
      allow(Spree::WebhookMailer).to receive(:endpoint_disabled).and_return(mail_message)
    end

    it 'deactivates the endpoint with a reason' do
      endpoint.disable!

      expect(endpoint.active).to be false
      expect(endpoint.disabled_reason).to be_present
      expect(endpoint.disabled_at).to be_present
    end

    it 'sends a notification email' do
      endpoint.disable!
      expect(Spree::WebhookMailer).to have_received(:endpoint_disabled).with(endpoint)
      expect(mail_message).to have_received(:deliver_later)
    end

    it 'accepts a custom reason' do
      endpoint.disable!(reason: 'Manual disable')
      expect(endpoint.disabled_reason).to eq('Manual disable')
    end

    it 'skips notification when notify: false' do
      endpoint.disable!(notify: false)
      expect(Spree::WebhookMailer).not_to have_received(:endpoint_disabled)
    end
  end

  describe '#enable!' do
    let(:endpoint) { create(:webhook_endpoint, :auto_disabled, store: store) }

    it 're-enables the endpoint and clears disable fields' do
      endpoint.enable!

      expect(endpoint.active).to be true
      expect(endpoint.disabled_reason).to be_nil
      expect(endpoint.disabled_at).to be_nil
    end
  end

  describe '#check_auto_disable!' do
    let(:endpoint) { create(:webhook_endpoint, store: store) }
    let(:mail_message) { double('Mail', deliver_later: true) }

    before do
      allow(Spree::WebhookMailer).to receive(:endpoint_disabled).and_return(mail_message)
    end

    context 'when consecutive failures reach threshold' do
      before do
        Spree::WebhookEndpoint::AUTO_DISABLE_THRESHOLD.times do
          create(:webhook_delivery, :failed, webhook_endpoint: endpoint)
        end
      end

      it 'disables the endpoint' do
        endpoint.check_auto_disable!

        expect(endpoint.reload.active).to be false
        expect(endpoint.disabled_at).to be_present
      end
    end

    context 'when failures are below threshold' do
      before do
        (Spree::WebhookEndpoint::AUTO_DISABLE_THRESHOLD - 1).times do
          create(:webhook_delivery, :failed, webhook_endpoint: endpoint)
        end
      end

      it 'does not disable the endpoint' do
        endpoint.check_auto_disable!
        expect(endpoint.reload.active).to be true
      end
    end

    context 'when a success is interspersed among failures' do
      before do
        # Create failures, then a success, then more failures
        8.times { create(:webhook_delivery, :failed, webhook_endpoint: endpoint) }
        create(:webhook_delivery, :successful, webhook_endpoint: endpoint)
        7.times { create(:webhook_delivery, :failed, webhook_endpoint: endpoint) }
      end

      it 'does not disable (consecutive count resets at success)' do
        endpoint.check_auto_disable!
        expect(endpoint.reload.active).to be true
      end
    end

    context 'when already auto-disabled' do
      let(:endpoint) { create(:webhook_endpoint, :auto_disabled, store: store) }

      it 'does nothing' do
        expect { endpoint.check_auto_disable! }.not_to change { endpoint.reload.disabled_at }
      end
    end
  end

  describe 'soft delete' do
    let!(:endpoint) { create(:webhook_endpoint, store: store) }

    it 'soft deletes the record' do
      endpoint.destroy
      expect(endpoint.deleted_at).to be_present
      expect(described_class.with_deleted.find(endpoint.id)).to eq(endpoint)
    end
  end
end
