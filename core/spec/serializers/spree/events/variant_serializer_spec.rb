# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::VariantSerializer do
  let(:product) { create(:product) }
  let(:variant) { create(:variant, product: product, sku: 'TEST-SKU-001') }

  subject { described_class.serialize(variant) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(variant.prefix_id)
      expect(subject[:sku]).to eq('TEST-SKU-001')
    end

    it 'includes barcode' do
      expect(subject).to have_key(:barcode)
    end

    it 'includes is_master' do
      expect(subject[:is_master]).to eq(variant.is_master)
    end

    it 'includes position' do
      expect(subject).to have_key(:position)
    end

    it 'includes dimensions' do
      expect(subject).to have_key(:weight)
      expect(subject).to have_key(:height)
      expect(subject).to have_key(:width)
      expect(subject).to have_key(:depth)
      expect(subject).to have_key(:weight_unit)
      expect(subject).to have_key(:dimensions_unit)
    end

    it 'includes cost fields' do
      expect(subject).to have_key(:cost_price)
      expect(subject).to have_key(:cost_currency)
    end

    it 'includes track_inventory' do
      expect(subject).to have_key(:track_inventory)
    end

    it 'includes foreign keys' do
      expect(subject[:product_id]).to eq(product.prefix_id)
      expect(subject).to have_key(:tax_category_id)
    end

    it 'includes discontinue_on' do
      expect(subject).to have_key(:discontinue_on)
    end

    it 'includes deleted_at' do
      expect(subject).to have_key(:deleted_at)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
