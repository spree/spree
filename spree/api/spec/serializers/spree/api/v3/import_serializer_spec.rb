# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::ImportSerializer do
  let(:store) { @default_store }
  let(:import) { create(:import) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(import, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id number type status owner_type owner_id user_id rows_count created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(import.prefixed_id)
  end

  it 'returns prefixed user_id' do
    expect(subject['user_id']).to eq(import.user.prefixed_id)
  end

  it 'returns status as string' do
    expect(subject['status']).to be_a(String)
  end
end
