# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::AssetSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store]) }
  let(:asset) { create(:asset, viewable: product.master) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(asset, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id type viewable_type viewable_id position alt created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(asset.prefixed_id)
  end

  it 'returns prefixed viewable_id' do
    expect(subject['viewable_id']).to eq(product.master.prefixed_id)
  end

  it 'returns viewable_type' do
    expect(subject['viewable_type']).to eq('Spree::Variant')
  end
end
