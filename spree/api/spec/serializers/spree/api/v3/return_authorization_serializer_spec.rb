# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::ReturnAuthorizationSerializer do
  let(:store) { @default_store }
  let(:return_authorization) { create(:return_authorization) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(return_authorization, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id number state order_id stock_location_id return_authorization_reason_id created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(return_authorization.prefixed_id)
  end

  it 'returns prefixed order_id' do
    expect(subject['order_id']).to eq(return_authorization.order.prefixed_id)
  end

  it 'returns state as string' do
    expect(subject['state']).to be_a(String)
  end
end
