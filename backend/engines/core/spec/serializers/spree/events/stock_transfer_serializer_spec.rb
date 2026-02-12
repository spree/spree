# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::StockTransferSerializer do
  let(:source_location) { create(:stock_location, name: 'Source') }
  let(:destination_location) { create(:stock_location, name: 'Destination') }
  let(:stock_transfer) do
    create(:stock_transfer,
           source_location: source_location,
           destination_location: destination_location,
           reference: 'REF123')
  end

  subject { described_class.serialize(stock_transfer) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(stock_transfer.prefixed_id)
      expect(subject[:number]).to eq(stock_transfer.number)
    end

    it 'includes type' do
      expect(subject).to have_key(:type)
    end

    it 'includes reference' do
      expect(subject[:reference]).to eq('REF123')
    end

    it 'includes location foreign keys' do
      expect(subject[:source_location_id]).to eq(source_location.prefixed_id)
      expect(subject[:destination_location_id]).to eq(destination_location.prefixed_id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
