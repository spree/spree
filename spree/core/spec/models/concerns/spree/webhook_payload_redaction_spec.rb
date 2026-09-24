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
      expect(secrets).to eq('data.reset_token' => 'live-token')
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
      expect(secrets).to eq('data.verification_token' => 'live-token')
      expect(described_class.merge(payload, secrets)).to eq(original)
    end

    # Payment session events carry live gateway credentials: a client secret
    # confirms a payment and an ephemeral key lists a customer's saved cards.
    it 'redacts payment session credentials nested inside external_data' do
      original = {
        'name' => 'payment_session.created',
        'data' => {
          'status' => 'pending',
          'external_client_secret' => 'seti_live_secret',
          'external_data' => {
            'client_secret' => 'pi_live_secret',
            'ephemeral_key_secret' => 'ek_live_secret',
            'payment_intent_id' => 'pi_123'
          }
        }
      }

      payload, secrets = described_class.split(original)

      expect(payload['data']['external_client_secret']).to eq(placeholder)
      expect(payload['data']['external_data']['client_secret']).to eq(placeholder)
      expect(payload['data']['external_data']['ephemeral_key_secret']).to eq(placeholder)
      expect(payload['data']['external_data']['payment_intent_id']).to eq('pi_123')
      expect(secrets).to eq(
        'data.external_client_secret' => 'seti_live_secret',
        'data.external_data.client_secret' => 'pi_live_secret',
        'data.external_data.ephemeral_key_secret' => 'ek_live_secret'
      )
      expect(described_class.merge(payload, secrets)).to eq(original)
    end

    # Keying by path alone: two secrets sharing a key name must not overwrite
    # one another on the way out or back in.
    it 'keeps same-named secrets at different depths apart' do
      original = {
        'data' => {
          'client_secret' => 'top-level',
          'external_data' => { 'client_secret' => 'nested' }
        }
      }

      payload, secrets = described_class.split(original)

      expect(secrets).to eq('data.client_secret' => 'top-level', 'data.external_data.client_secret' => 'nested')
      expect(described_class.merge(payload, secrets)).to eq(original)
    end

    it 'redacts secrets inside arrays of nested records' do
      original = { 'data' => { 'sessions' => [{ 'client_secret' => 'one' }, { 'client_secret' => 'two' }] } }

      payload, secrets = described_class.split(original)

      expect(payload['data']['sessions'].map { |session| session['client_secret'] }).to all(eq(placeholder))
      expect(described_class.merge(payload, secrets)).to eq(original)
    end

    # A key that itself contains the path separator must not be mistaken for
    # two nested keys, or `merge` restores the wrong credential.
    it 'keeps a dotted key name distinct from the nested path it resembles' do
      original = {
        'data' => {
          'external.data' => { 'client_secret' => 'from-dotted-parent' },
          'external' => { 'data' => { 'client_secret' => 'from-nested' } }
        }
      }

      payload, secrets = described_class.split(original)

      expect(secrets.values).to contain_exactly('from-dotted-parent', 'from-nested')
      expect(described_class.merge(payload, secrets)).to eq(original)
    end

    # The escape character is itself escaped, so a key carrying a backslash
    # cannot forge the encoding of a different path.
    it 'keeps a key containing a backslash distinct from the path it imitates' do
      original = {
        'data' => {
          'a\\' => { 'b' => { 'client_secret' => 'from-backslash-parent' } },
          'a' => { 'b' => { 'client_secret' => 'from-plain-parent' } }
        }
      }

      payload, secrets = described_class.split(original)

      expect(secrets.values).to contain_exactly('from-backslash-parent', 'from-plain-parent')
      expect(described_class.merge(payload, secrets)).to eq(original)
    end

    # Both roots key their secrets identically on purpose: the payload is
    # persisted as JSON and read back with string keys, so a symbol root that
    # keyed itself separately would restore nothing after the round trip.
    it 'keys both data roots the same way' do
      payload, secrets = described_class.split(
        :data => { 'client_secret' => 'sym-side' },
        'data' => { 'client_secret' => 'str-side' }
      )

      expect(payload[:data]['client_secret']).to eq(placeholder)
      expect(payload['data']['client_secret']).to eq(placeholder)
      expect(secrets.keys).to eq(['data.client_secret'])
    end

    # The guest cart token lets whoever holds it read and change the cart,
    # so it must not sit in a log that `read_webhooks` can read.
    it 'redacts the guest cart token' do
      original = { name: 'cart.updated', data: { id: 'cart_1', token: 'guest-token' } }

      payload, secrets = described_class.split(original)

      expect(payload[:data][:token]).to eq(placeholder)
      expect(described_class.merge(payload, secrets)).to eq(original)
    end

    it "redacts a gift card event's code" do
      original = { name: 'gift_card.created', data: { id: 'gc_1', code: 'SPEND-ME' } }

      payload, secrets = described_class.split(original)

      expect(payload[:data][:code]).to eq(placeholder)
      expect(described_class.merge(payload, secrets)).to eq(original)
    end

    it 'redacts the code of a gift card applied to an order' do
      original = { name: 'order.completed', data: { id: 'or_1', gift_card: { id: 'gc_1', code: 'SPEND-ME' } } }

      payload, secrets = described_class.split(original)

      expect(payload[:data][:gift_card][:code]).to eq(placeholder)
      expect(described_class.merge(payload, secrets)).to eq(original)
    end

    # Promotion, country and channel codes are not credentials.
    it 'leaves other codes alone' do
      original = { name: 'order.completed', data: { id: 'or_1', code: 'R123', market: { code: 'eu' } } }

      expect(described_class.split(original)).to eq([original, {}])
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
      expect(secrets.keys).to eq(['data.reset_token'])
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

    # Only a slot still holding the placeholder is filled. A value the payload
    # legitimately carries is never replaced by a secret of the same name.
    it 'does not overwrite a value that is not the placeholder' do
      redacted = { 'data' => { 'external_data' => { 'client_secret' => 'a-real-value' } } }

      restored = described_class.merge(redacted, 'data.external_data.client_secret' => 'live-secret')

      expect(restored['data']['external_data']['client_secret']).to eq('a-real-value')
    end

    # Deliveries queued before path keying carry bare key names. That form only
    # ever came from the top level, so it must not fill same-named slots deeper
    # in the tree.
    it 'confines a legacy bare-keyed secret to the top level of data' do
      redacted = {
        'data' => {
          'reset_token' => placeholder,
          'child' => { 'reset_token' => placeholder }
        }
      }

      restored = described_class.merge(redacted, 'reset_token' => 'live-token')

      expect(restored['data']['reset_token']).to eq('live-token')
      expect(restored['data']['child']['reset_token']).to eq(placeholder)
    end
  end

  it 'round-trips to the original payload' do
    original = { 'data' => { 'email' => 'a@example.com', 'reset_token' => 'live-token' } }

    expect(described_class.merge(*described_class.split(original))).to eq(original)
  end
end
