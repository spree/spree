# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::StockMovementSerializer do
  let(:stock_location) { create(:stock_location) }
  let(:variant) { create(:variant) }
  let(:stock_item) { variant.stock_items.first || create(:stock_item, variant: variant, stock_location: stock_location) }
  let(:stock_movement) { create(:stock_movement, stock_item: stock_item, quantity: 5) }

  subject { described_class.serialize(stock_movement) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(stock_movement.prefixed_id)
    end

    it 'includes quantity' do
      expect(subject[:quantity]).to eq(5)
    end

    it 'includes action' do
      expect(subject).to have_key(:action)
    end

    it 'includes originator polymorphic reference' do
      expect(subject).to have_key(:originator_type)
      expect(subject).to have_key(:originator_id)
    end

    it 'includes stock_item_id' do
      expect(subject[:stock_item_id]).to eq(stock_item.prefixed_id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
