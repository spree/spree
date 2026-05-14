# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PaymentMethodSerializer do
  let(:store) { @default_store }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'preferences masking' do
    let(:payment_method) do
      pm = create(:bogus_payment_method, stores: [store])
      pm.set_preference(:dummy_secret_key, 'sk_live_super_secret_value')
      pm.set_preference(:dummy_key, 'pk_live_visible_key')
      pm.save!
      pm
    end

    subject(:payload) { described_class.new(payment_method, params: base_params).to_h }

    it 'masks `:password` preferences in the serialized payload' do
      expect(payload['preferences']['dummy_secret_key']).to eq("#{Spree::Preferences::Masking::TOKEN}alue")
    end

    it 'never includes the plaintext secret anywhere in the payload' do
      expect(payload.to_json).not_to include('sk_live_super_secret_value')
    end

    it 'returns non-password preferences in plaintext' do
      expect(payload['preferences']['dummy_key']).to eq('pk_live_visible_key')
    end

    # Bogus declares `preference :dummy_secret_key, :password, default: 'SECRETKEY123'`.
    # A non-empty default on a password preference is itself a secret —
    # `serialized_preference_schema` must nil it out before it hits the wire.
    it 'redacts password defaults in preference_schema' do
      password_field = payload['preference_schema'].find { |f| f[:key] == :dummy_secret_key }
      expect(password_field).not_to be_nil
      expect(password_field[:default]).to be_nil
      expect(payload.to_json).not_to include('SECRETKEY123')
    end

    # `:key_string` is an internal cache used by `Masking.serialize` to
    # avoid `to_s` allocations per request. It must not leak into the
    # wire payload — the documented shape is `{ key, type, default }`.
    it 'does not expose the internal :key_string cache in preference_schema entries' do
      expect(payload['preference_schema']).to all(have_key(:key))
      expect(payload['preference_schema']).to all(have_key(:type))
      expect(payload['preference_schema']).to all(have_key(:default))
      expect(payload['preference_schema']).not_to include(have_key(:key_string))
    end
  end
end
