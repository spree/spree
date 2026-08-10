# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::DigitalAssetSerializer do
  let(:store) { @default_store }
  let(:digital_asset) { create(:digital_asset) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(digital_asset, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id variant_id filename content_type
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(digital_asset.prefixed_id)
  end

  it 'returns prefixed variant_id' do
    expect(subject['variant_id']).to eq(digital_asset.variant.prefixed_id)
  end

  it 'returns the attachment filename' do
    expect(subject['filename']).to eq('thinking-cat.jpg')
  end

  describe Spree::Api::V3::Admin::DigitalAssetSerializer do
    subject { described_class.new(digital_asset, params: base_params).to_h }

    it 'adds back-office attributes' do
      expect(subject.keys).to include(
        'byte_size', 'authorized_clicks', 'authorized_days',
        'effective_authorized_clicks', 'effective_authorized_days',
        'created_at', 'updated_at'
      )
    end

    it 'exposes the store fallback in the effective limits' do
      store.update!(preferred_digital_asset_authorized_clicks: 5)

      expect(subject['authorized_clicks']).to be_nil
      expect(subject['effective_authorized_clicks']).to eq(5)
    end
  end
end
