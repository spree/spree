require 'spec_helper'

RSpec.describe Spree::Api::V3::PaymentMethodSerializer do
  let(:store) { @default_store }

  subject(:payload) { described_class.new(payment_method, params: { store: store, currency: 'USD' }).to_h }

  context 'with a provider that declares public preferences' do
    let(:payment_method) do
      create(:bogus_payment_method, store: store).tap do |method|
        method.set_preference(:dummy_key, 'pk_test_storefront')
        method.set_preference(:dummy_secret_key, 'sk_test_secret')
        method.save!
      end
    end

    it 'sends only those, so the storefront can load the right account' do
      expect(payload['public_preferences'].stringify_keys).to eq('dummy_key' => 'pk_test_storefront')
      expect(payload.to_json).not_to include('sk_test_secret')
    end
  end

  context 'with a provider that declares none' do
    let(:payment_method) { create(:check_payment_method, store: store) }

    it 'sends an empty object' do
      expect(payload['public_preferences']).to eq({})
    end
  end
end
