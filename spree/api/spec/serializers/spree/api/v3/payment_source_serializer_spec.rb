require 'spec_helper'

RSpec.describe Spree::Api::V3::PaymentSourceSerializer do
  let(:store) { @default_store }
  let(:payment_method) { create(:custom_payment_method, stores: [store]) }
  let(:payment_source) do
    create(:payment_source,
           payment_method: payment_method,
           gateway_payment_profile_id: 'pp_abc123')
  end
  let(:base_params) { { store: store, currency: store.default_currency } }

  subject { described_class.new(payment_source, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id gateway_payment_profile_id
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(payment_source.prefixed_id)
  end

  it 'returns correct attribute values' do
    expect(subject['gateway_payment_profile_id']).to eq('pp_abc123')
  end

  context 'without gateway_payment_profile_id' do
    let(:payment_source) { create(:payment_source, payment_method: payment_method, gateway_payment_profile_id: nil) }

    it 'returns nil for gateway_payment_profile_id' do
      expect(subject['gateway_payment_profile_id']).to be_nil
    end
  end

  it 'does not expose metadata in Store API responses' do
    payment_source.update!(public_metadata: { 'email' => 'user@example.com' })
    expect(subject).not_to have_key('public_metadata')
    expect(subject).not_to have_key('metadata')
  end
end
