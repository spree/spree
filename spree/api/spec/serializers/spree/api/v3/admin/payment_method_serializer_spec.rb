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
      expect(payload['preferences']['dummy_secret_key']).to eq('••••alue')
    end

    it 'never includes the plaintext secret anywhere in the payload' do
      expect(payload.to_json).not_to include('sk_live_super_secret_value')
    end

    it 'returns non-password preferences in plaintext' do
      expect(payload['preferences']['dummy_key']).to eq('pk_live_visible_key')
    end

    # The `preference_schema` attribute also exposes a `default` value for
    # every preference key. A gateway author can set a non-empty default
    # for a `:password` preference (Bogus does — `'SECRETKEY123'`); that
    # default would otherwise leak through the schema even though the
    # `preferences` hash is masked.
    it 'redacts password defaults in preference_schema' do
      password_field = payload['preference_schema'].find { |f| f[:key] == :dummy_secret_key || f['key'] == 'dummy_secret_key' }
      expect(password_field).not_to be_nil
      default = password_field[:default] || password_field['default']
      expect(default).to be_nil
      expect(payload.to_json).not_to include('SECRETKEY123')
    end
  end
end
