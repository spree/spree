# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PaymentMethodSerializer do
  let(:store) { @default_store }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'preferences masking' do
    let(:payment_method) do
      pm = create(:bogus_payment_method)
      pm.set_preference(:dummy_secret_key, 'sk_live_super_secret_value')
      pm.set_preference(:dummy_key, 'pk_live_visible_key')
      pm.save!
      pm
    end

    subject(:payload) { described_class.new(payment_method, params: base_params).to_h }

    it 'masks `:password` preferences in the serialized payload' do
      expect(payload['preferences']['dummy_secret_key']).to eq(Spree::Preferences::Masking.mask('sk_live_super_secret_value'))
    end

    it 'never includes the plaintext secret anywhere in the payload' do
      expect(payload.to_json).not_to include('sk_live_super_secret_value')
    end

    it 'returns non-password preferences in plaintext' do
      expect(payload['preferences']['dummy_key']).to eq('pk_live_visible_key')
    end

    # Bogus declares `preference :dummy_secret_key, :password, default: 'SECRETKEY123'`.
    # A non-empty default on a password preference is itself a secret. Rows
    # carry no schema at all — it lives on `/payment_methods/types`.
    it 'carries no preference schema, so no secret default reaches the wire' do
      expect(payload).not_to have_key('preference_schema')
      expect(payload.to_json).not_to include('SECRETKEY123')
    end
  end

  describe 'third_party' do
    it 'is true for a gateway backed by an external provider' do
      payload = described_class.new(create(:bogus_payment_method), params: base_params).to_h

      expect(payload['third_party']).to be(true)
    end

    it 'is false for a method the store handles itself' do
      payload = described_class.new(create(:check_payment_method), params: base_params).to_h

      expect(payload['third_party']).to be(false)
    end
  end
end
