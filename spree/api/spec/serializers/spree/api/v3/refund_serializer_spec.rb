# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::RefundSerializer do
  let(:store) { @default_store }
  let(:payment) { create(:payment, amount: 100, state: 'completed') }
  let(:refund) { create(:refund, payment: payment, amount: 10) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(refund, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id amount transaction_id payment_id refund_reason_id reimbursement_id created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(refund.prefixed_id)
  end

  it 'returns amount as string' do
    expect(subject['amount']).to eq('10.0')
  end

  it 'returns prefixed payment_id' do
    expect(subject['payment_id']).to eq(refund.payment.prefixed_id)
  end
end
