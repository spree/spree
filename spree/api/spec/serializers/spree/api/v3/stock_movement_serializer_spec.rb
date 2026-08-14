# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::StockMovementSerializer do
  let(:store) { @default_store }
  let(:stock_movement) { create(:stock_movement) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(stock_movement, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id quantity action originator_type originator_id stock_level_id created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(stock_movement.prefixed_id)
  end

  it 'returns prefixed stock_level_id' do
    expect(subject['stock_level_id']).to eq(stock_movement.stock_level.prefixed_id)
  end
end
