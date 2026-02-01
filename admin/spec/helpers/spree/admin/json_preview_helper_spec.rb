# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Admin::JsonPreviewHelper, type: :helper do
  let(:product) { create(:product) }
  let(:order) { create(:order) }

  describe '#store_serializer_exists?' do
    it 'returns true for Product' do
      expect(helper.store_serializer_exists?(product)).to be true
    end

    it 'returns true for Order' do
      expect(helper.store_serializer_exists?(order)).to be true
    end
  end

  describe '#admin_serializer_exists?' do
    it 'returns true for Product when admin serializer exists' do
      expect(helper.admin_serializer_exists?(product)).to be true
    end

    it 'returns true for Order when admin serializer exists' do
      expect(helper.admin_serializer_exists?(order)).to be true
    end
  end

  describe '#serialize_to_json' do
    context 'with store api_type' do
      it 'serializes Product to JSON' do
        json = helper.serialize_to_json(product, api_type: :store)
        expect(json).to be_present
        parsed = JSON.parse(json)
        expect(parsed['name']).to eq(product.name)
        expect(parsed['id']).to eq(product.prefix_id)
      end

      it 'serializes Order to JSON' do
        json = helper.serialize_to_json(order, api_type: :store)
        expect(json).to be_present
        parsed = JSON.parse(json)
        expect(parsed['number']).to eq(order.number)
        expect(parsed['id']).to eq(order.prefix_id)
      end
    end

    context 'with admin api_type' do
      it 'serializes Product with admin serializer' do
        json = helper.serialize_to_json(product, api_type: :admin)
        expect(json).to be_present
        parsed = JSON.parse(json)
        expect(parsed['name']).to eq(product.name)
      end
    end

    it 'returns nil for record without serializer' do
      # Create a mock model that doesn't have a serializer
      unknown_class = Class.new do
        def self.name
          'Spree::UnknownModel'
        end
      end
      record = unknown_class.new

      expect(helper.serialize_to_json(record, api_type: :store)).to be_nil
    end
  end
end
