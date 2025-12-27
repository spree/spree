# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::ShipmentSerializer do
  let(:shipment) { create(:shipment) }

  subject { described_class.serialize(shipment) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(shipment.id)
      expect(subject[:number]).to eq(shipment.number)
    end

    it 'includes state as string' do
      expect(subject[:state]).to be_a(String)
    end

    it 'includes tracking' do
      expect(subject).to have_key(:tracking)
    end

    it 'includes cost' do
      expect(subject).to have_key(:cost)
    end

    it 'includes foreign keys' do
      expect(subject[:order_id]).to eq(shipment.order_id)
      expect(subject[:stock_location_id]).to eq(shipment.stock_location_id)
    end

    it 'includes timestamps' do
      expect(subject).to have_key(:shipped_at)
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end

    it 'does not include associations' do
      expect(subject).not_to have_key(:inventory_units)
      expect(subject).not_to have_key(:shipping_rates)
    end
  end
end
