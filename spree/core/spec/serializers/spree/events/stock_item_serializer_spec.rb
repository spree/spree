# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::StockItemSerializer do
  let(:stock_location) { create(:stock_location) }
  let(:variant) { create(:variant) }
  let(:stock_item) { variant.stock_items.first || create(:stock_item, variant: variant, stock_location: stock_location) }

  subject { described_class.serialize(stock_item) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(stock_item.prefixed_id)
    end

    it 'includes count_on_hand' do
      expect(subject).to have_key(:count_on_hand)
    end

    it 'includes backorderable' do
      expect(subject).to have_key(:backorderable)
    end

    it 'includes foreign keys' do
      expect(subject[:stock_location_id]).to eq(stock_item.stock_location&.prefixed_id)
      expect(subject[:variant_id]).to eq(stock_item.variant&.prefixed_id)
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
