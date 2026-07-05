# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::StockTransferSerializer do
  let(:store) { @default_store }
  let(:stock_transfer) { create(:stock_transfer) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(stock_transfer, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id number type reference source_location_id destination_location_id created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(stock_transfer.prefixed_id)
  end

  it 'returns prefixed source_location_id' do
    expect(subject['source_location_id']).to eq(stock_transfer.source_location.prefixed_id)
  end

  it 'returns prefixed destination_location_id' do
    expect(subject['destination_location_id']).to eq(stock_transfer.destination_location.prefixed_id)
  end
end
