# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::ExportSerializer do
  let(:store) { @default_store }
  let(:export) { create(:export) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(export, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id number type format user_id created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(export.prefixed_id)
  end

  it 'returns prefixed user_id' do
    expect(subject['user_id']).to eq(export.user.prefixed_id)
  end

  it 'returns the export type' do
    expect(subject['type']).to eq('Spree::Exports::Products')
  end
end
