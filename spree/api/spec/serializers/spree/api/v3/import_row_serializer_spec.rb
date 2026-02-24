# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::ImportRowSerializer do
  let(:store) { @default_store }
  let(:import_row) { create(:import_row) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(import_row, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id import_id row_number status validation_errors item_type item_id created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(import_row.prefixed_id)
  end

  it 'returns prefixed import_id' do
    expect(subject['import_id']).to eq(import_row.import.prefixed_id)
  end
end
