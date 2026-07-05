# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::DigitalSerializer do
  let(:store) { @default_store }
  let(:digital) { create(:digital) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(digital, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id variant_id created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(digital.prefixed_id)
  end

  it 'returns prefixed variant_id' do
    expect(subject['variant_id']).to eq(digital.variant.prefixed_id)
  end
end
