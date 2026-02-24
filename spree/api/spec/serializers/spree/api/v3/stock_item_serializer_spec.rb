# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::StockItemSerializer do
  let(:store) { @default_store }
  let(:stock_item) { create(:stock_item) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(stock_item, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id count_on_hand backorderable stock_location_id variant_id created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(stock_item.prefixed_id)
  end

  it 'returns prefixed stock_location_id' do
    expect(subject['stock_location_id']).to eq(stock_item.stock_location.prefixed_id)
  end

  it 'returns prefixed variant_id' do
    expect(subject['variant_id']).to eq(stock_item.variant.prefixed_id)
  end

  it 'returns count_on_hand as number' do
    expect(subject['count_on_hand']).to be_a(Integer)
  end
end
