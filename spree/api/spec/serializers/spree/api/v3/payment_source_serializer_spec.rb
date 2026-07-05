require 'spec_helper'

RSpec.describe Spree::Api::V3::PaymentSourceSerializer do
  let(:store) { @default_store }
  let(:payment_method) { create(:custom_payment_method) }
  let(:payment_source) do
    create(:payment_source,
           payment_method: payment_method,
           gateway_payment_profile_id: 'pp_abc123')
  end
  let(:base_params) { { store: store, currency: store.default_currency } }

  subject { described_class.new(payment_source, params: base_params).to_h }

  it 'includes expected attributes' do
    expect(subject.keys).to match_array(%w[id gateway_payment_profile_id])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(payment_source.prefixed_id)
  end

  it 'exposes gateway_payment_profile_id for saved payment method flows' do
    expect(subject['gateway_payment_profile_id']).to eq('pp_abc123')
  end

  it 'does not expose metadata in Store API responses' do
    payment_source.update!(public_metadata: { 'email' => 'user@example.com' })
    expect(subject).not_to have_key('public_metadata')
    expect(subject).not_to have_key('metadata')
  end
end
