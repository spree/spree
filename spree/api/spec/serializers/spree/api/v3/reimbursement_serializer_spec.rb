# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::ReimbursementSerializer do
  let(:store) { @default_store }
  let(:reimbursement) { create(:reimbursement) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(reimbursement, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id number reimbursement_status total order_id customer_return_id created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(reimbursement.prefixed_id)
  end

  it 'returns prefixed order_id' do
    expect(subject['order_id']).to eq(reimbursement.order.prefixed_id)
  end
end
