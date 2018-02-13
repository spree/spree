require 'spec_helper'

module Spree
  describe StockTransfer, type: :model do
    subject { StockTransfer.create(reference: 'PO123') }

    let(:destination_location) { create(:stock_location_with_items) }
    let(:source_location) { create(:stock_location_with_items) }
    let(:stock_item) { source_location.stock_items.order(:id).first }
    let(:variant) { stock_item.variant }

    describe '#reference' do
      subject { super().reference }

      it { is_expected.to eq 'PO123' }
    end

    describe '#to_param' do
      subject { super().to_param }

      it { is_expected.to match(/T\d+/) }
    end

    it 'transfers variants between 2 locations' do
      variants = { variant => 5 }

      subject.transfer(source_location,
                       destination_location,
                       variants)

      expect(source_location.count_on_hand(variant)).to eq 5
      expect(destination_location.count_on_hand(variant)).to eq 5

      expect(subject.source_location).to eq source_location
      expect(subject.destination_location).to eq destination_location

      expect(subject.source_movements.first.quantity).to eq(-5)
      expect(subject.destination_movements.first.quantity).to eq 5
    end

    it 'receive new inventory (from a vendor)' do
      variants = { variant => 5 }

      subject.receive(destination_location, variants)

      expect(destination_location.count_on_hand(variant)).to eq 5

      expect(subject.source_location).to be_nil
      expect(subject.destination_location).to eq destination_location
    end
  end
end
