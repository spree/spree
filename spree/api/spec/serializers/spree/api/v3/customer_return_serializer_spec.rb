# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::CustomerReturnSerializer do
  let(:store) { @default_store }
  let(:customer_return) { create(:customer_return) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(customer_return, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id number stock_location_id created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(customer_return.prefixed_id)
  end

  it 'returns prefixed stock_location_id' do
    expect(subject['stock_location_id']).to eq(customer_return.stock_location.prefixed_id)
  end
end
