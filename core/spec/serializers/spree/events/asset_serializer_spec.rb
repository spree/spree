# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::AssetSerializer do
  subject { described_class.serialize(asset) }

  let(:product) { create(:product) }
  let(:variant) { product.master }
  let(:asset) { create(:image, viewable: variant) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(asset.id)
      expect(subject[:type]).to eq(asset.type)
    end

    it 'includes viewable polymorphic reference' do
      expect(subject[:viewable_type]).to eq('Spree::Variant')
      expect(subject[:viewable_id]).to eq(variant.id)
    end

    it 'includes position' do
      expect(subject).to have_key(:position)
    end

    it 'includes alt text' do
      expect(subject).to have_key(:alt)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
