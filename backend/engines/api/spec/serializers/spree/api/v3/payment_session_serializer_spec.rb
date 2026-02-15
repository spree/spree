require 'spec_helper'

RSpec.describe Spree::Api::V3::PaymentSessionSerializer do
  let(:store) { @default_store }
  let(:order) { create(:order, store: store) }
  let(:payment_method) { create(:bogus_payment_method, stores: [store]) }
  let(:payment_session) do
    create(:bogus_payment_session,
           order: order,
           payment_method: payment_method,
           amount: 99.99,
           currency: 'USD',
           external_data: { 'client_secret' => 'secret_123', 'channel' => 'Web' },
           expires_at: 24.hours.from_now,
           customer_external_id: 'cus_abc123')
  end
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(payment_session, params: base_params).to_h }

  describe 'serialized attributes' do
    it 'includes standard attributes' do
      expect(subject).to include(
        'id' => payment_session.prefixed_id,
        'status' => 'pending',
        'amount' => '99.99',
        'currency' => 'USD',
        'customer_external_id' => 'cus_abc123'
      )
    end

    it 'includes external_data' do
      expect(subject['external_data']).to eq({ 'client_secret' => 'secret_123', 'channel' => 'Web' })
    end

    it 'includes prefixed payment_method_id' do
      expect(subject['payment_method_id']).to eq(payment_method.prefixed_id)
    end

    it 'includes prefixed order_id' do
      expect(subject['order_id']).to eq(order.prefixed_id)
    end

    it 'includes timestamp attributes' do
      expect(subject).to have_key('created_at')
      expect(subject).to have_key('updated_at')
    end

    it 'includes expires_at' do
      expect(subject['expires_at']).to be_present
    end
  end
end
