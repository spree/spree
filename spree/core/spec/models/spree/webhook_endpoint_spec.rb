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

  describe 'scopes' do
    let!(:active_endpoint) { create(:webhook_endpoint, store: store, active: true) }
    let!(:inactive_endpoint) { create(:webhook_endpoint, :inactive, store: store) }

    describe '.active' do
      it 'returns only active endpoints' do
        expect(described_class.active).to include(active_endpoint)
        expect(described_class.active).not_to include(inactive_endpoint)
      end
    end

    describe '.inactive' do
      it 'returns only inactive endpoints' do
        expect(described_class.inactive).to include(inactive_endpoint)
        expect(described_class.inactive).not_to include(active_endpoint)
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

  describe 'soft delete' do
    let!(:endpoint) { create(:webhook_endpoint, store: store) }

    it 'soft deletes the record' do
      endpoint.destroy
      expect(endpoint.deleted_at).to be_present
      expect(described_class.with_deleted.find(endpoint.id)).to eq(endpoint)
    end
  end
end
