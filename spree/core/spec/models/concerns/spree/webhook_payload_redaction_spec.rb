# frozen_string_literal: true

require 'spec_helper'

describe Spree::WebhookPayloadRedaction do
  let(:placeholder) { described_class::REDACTION_PLACEHOLDER }

  describe '.split' do
    it 'extracts sensitive keys and replaces them with the placeholder' do
      payload, secrets = described_class.split(
        'name' => 'customer.password_reset_requested',
        'data' => { 'email' => 'a@example.com', 'reset_token' => 'live-token' }
      )

      expect(payload['data']['reset_token']).to eq(placeholder)
      expect(payload['data']['email']).to eq('a@example.com')
      expect(secrets).to eq('reset_token' => 'live-token')
    end

    it 'handles symbol keys' do
      original = { data: { unsubscribe_token: 'tok' } }

      payload, secrets = described_class.split(original)

      expect(payload[:data][:unsubscribe_token]).to eq(placeholder)
      expect(described_class.merge(payload, secrets)).to eq(original)
    end

    # The newsletter double opt-in event carries a live has_secure_token that
    # must never land in the persisted delivery log.
    it 'redacts the newsletter verification_token and re-attaches it at send time' do
      original = {
        'name' => 'newsletter_subscriber.subscription_requested',
        'data' => { 'email' => 'a@example.com', 'verification_token' => 'live-token' }
      }

      payload, secrets = described_class.split(original)

      expect(payload['data']['verification_token']).to eq(placeholder)
      expect(payload['data']['email']).to eq('a@example.com')
      expect(secrets).to eq('verification_token' => 'live-token')
      expect(described_class.merge(payload, secrets)).to eq(original)
    end

    it 'returns the payload untouched when nothing is sensitive' do
      original = { 'data' => { 'number' => 'R123' } }

      expect(described_class.split(original)).to eq([original, {}])
    end

    it 'ignores payloads without a data hash' do
      expect(described_class.split('data' => nil)).to eq([{ 'data' => nil }, {}])
    end

    it 'redacts both data hashes when the payload carries :data and "data"' do
      payload, _secrets = described_class.split(
        :data => { 'reset_token' => 'sym-side' },
        'data' => { 'reset_token' => 'str-side' }
      )

      expect(payload[:data]['reset_token']).to eq(placeholder)
      expect(payload['data']['reset_token']).to eq(placeholder)
    end

    it 'redacts every form of a sensitive key present in the same data hash' do
      payload, secrets = described_class.split(
        'data' => { :reset_token => 'sym-tok', 'reset_token' => 'str-tok' }
      )

      expect(payload['data'].values).to all(eq(placeholder))
      expect(secrets.keys).to eq(['reset_token'])
    end

    # Secrets survive an ActiveJob round trip, which stringifies symbol keys.
    it 'restores a payload whose keys were stringified in transit' do
      _payload, secrets = described_class.split(data: { reset_token: 'live-token' })
      persisted = { 'data' => { 'reset_token' => placeholder } }

      restored = described_class.merge(persisted, JSON.parse(secrets.to_json))

      expect(restored['data']['reset_token']).to eq('live-token')
    end
  end

  describe '.merge' do
    it 'restores extracted secrets' do
      redacted = { 'data' => { 'email' => 'a@example.com', 'reset_token' => placeholder } }

      restored = described_class.merge(redacted, 'reset_token' => 'live-token')

      expect(restored['data']['reset_token']).to eq('live-token')
      expect(restored['data']['email']).to eq('a@example.com')
    end

    it 'leaves the payload redacted when no secrets are held' do
      redacted = { 'data' => { 'reset_token' => placeholder } }

      expect(described_class.merge(redacted, nil)).to eq(redacted)
    end
  end

  it 'round-trips to the original payload' do
    original = { 'data' => { 'email' => 'a@example.com', 'reset_token' => 'live-token' } }

    expect(described_class.merge(*described_class.split(original))).to eq(original)
  end
end
