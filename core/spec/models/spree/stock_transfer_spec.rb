require 'spec_helper'

module Spree
  describe StockTransfer, type: :model do
    subject { described_class.create(reference: 'PO123', source_location: source_location, destination_location: destination_location) }

    let(:destination_location) { create(:stock_location_with_items) }
    let(:source_location) { create(:stock_location_with_items) }
    let(:stock_item) { source_location.stock_items.order(:id).first }
    let(:variant) { stock_item.variant }

    it_behaves_like 'metadata'

    describe '#reference' do
      subject { super().reference }

      it { is_expected.to eq 'PO123' }
    end

    describe '#to_param' do
      subject { super().to_param }

      it { is_expected.to match(/T\d+/) }
    end

    describe '#transfer' do
      it 'transfers variants between 2 locations' do
        variants = { variant => 5 }

        subject.transfer(source_location, destination_location, variants)

        expect(source_location.count_on_hand(variant)).to eq 5
        expect(destination_location.count_on_hand(variant)).to eq 5

        expect(subject.source_location).to eq source_location
        expect(subject.destination_location).to eq destination_location

        expect(subject.source_movements.first.quantity).to eq(-5)
        expect(subject.destination_movements.first.quantity).to eq 5
      end

      context 'when variants are not available in the source location' do
        let(:other_variant) { create(:variant) }

        it 'does not transfer the variants' do
          expect(subject.transfer(source_location, destination_location, { variant => 5, other_variant => 5 })).to be false
          expect(subject.errors[:base]).to include(Spree.t('stock_transfer.errors.variants_unavailable'))
        end
      end

      context 'when variants are empty' do
        it 'does not transfer the variants' do
          expect(subject.transfer(source_location, destination_location, {})).to be false
          expect(subject.errors[:base]).to include(Spree.t('stock_transfer.errors.must_have_variant'))
        end
      end

      context 'when variants are nil' do
        it 'does not transfer the variants' do
          expect(subject.transfer(source_location, destination_location, nil)).to be false
          expect(subject.errors[:base]).to include(Spree.t('stock_transfer.errors.must_have_variant'))
        end
      end
    end

    it 'receive new inventory (from a vendor)' do
      variants = { variant => 5 }

      subject.receive(destination_location, variants)

      expect(destination_location.count_on_hand(variant)).to eq 5

      expect(subject.source_location).to be_nil
      expect(subject.destination_location).to eq destination_location
    end

    describe '#validations' do
      it 'checks if source location and destination location are the same' do
        expect(described_class.new(source_location: source_location, destination_location: source_location)).to be_invalid
        expect(described_class.new(source_location: source_location, destination_location: destination_location)).to be_valid
        expect(described_class.new(destination_location: destination_location)).to be_valid
      end
    end
  end
end
