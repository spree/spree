require 'spec_helper'

module Spree
  describe StockTransfer, type: :model do
    let(:stock_transfer) do
      create(
        :stock_transfer,
        reference: 'PO123',
        source_location: source_location,
        destination_location: destination_location
      )
    end

    let(:destination_location) { create(:stock_location_with_items) }
    let(:source_location) { create(:stock_location_with_items) }
    let(:stock_item) { source_location.stock_items.order(:id).first }
    let(:variant) { stock_item.variant }

    it_behaves_like 'metadata'

    describe '#reference' do
      subject { stock_transfer.reference }

      it { is_expected.to eq 'PO123' }
    end

    describe '#to_param' do
      subject { stock_transfer.to_param }

      it { is_expected.to match(/T\d+/) }
    end

    describe '#transfer' do
      subject { stock_transfer.transfer(source_location, destination_location, variants) }

      let(:stock_transfer) do
        build(
          :stock_transfer,
          reference: 'PO123',
          source_location: nil,
          destination_location: nil,
          stock_movements: []
        )
      end

      let(:variants) { { variant => 5 } }

      it 'transfers variants between 2 locations' do
        subject

        expect(source_location.count_on_hand(variant)).to eq 5
        expect(destination_location.count_on_hand(variant)).to eq 5

        expect(stock_transfer.source_location).to eq source_location
        expect(stock_transfer.destination_location).to eq destination_location

        expect(stock_transfer.source_movements.first.quantity).to eq(-5)
        expect(stock_transfer.destination_movements.first.quantity).to eq 5
      end

      context 'when variants are not available in the source location' do
        let(:variants) { { variant => 5, other_variant => 5 } }
        let(:other_variant) { create(:variant) }

        it 'does not transfer the variants' do
          expect(subject).to be false
          expect(stock_transfer.errors[:base]).to include(Spree.t('stock_transfer.errors.variants_unavailable'))
        end
      end

      context 'when variants are empty' do
        let(:variants) { {} }

        it 'does not transfer the variants' do
          expect(subject).to be false
          expect(stock_transfer.errors[:base]).to include(Spree.t('stock_transfer.errors.must_have_variant'))
        end
      end

      context 'when variants are nil' do
        let(:variants) { nil }

        it 'does not transfer the variants' do
          expect(subject).to be false
          expect(stock_transfer.errors[:base]).to include(Spree.t('stock_transfer.errors.must_have_variant'))
        end
      end
    end

    describe '#receive' do
      subject { stock_transfer.receive(destination_location, { variant => 5 }) }

      let(:stock_transfer) do
        build(
          :stock_transfer,
          reference: 'PO123',
          source_location: nil,
          destination_location: nil,
          stock_movements: []
        )
      end

      it 'receives new inventory (from a vendor)' do
        subject

        expect(destination_location.count_on_hand(variant)).to eq 5

        expect(stock_transfer.source_location).to be_nil
        expect(stock_transfer.destination_location).to eq destination_location
      end
    end

    describe '#validations' do
      it 'checks if source location and destination location are the same' do
        stock_movements = [build(:stock_movement)]

        expect(described_class.new(source_location: source_location, destination_location: source_location, stock_movements: stock_movements)).to be_invalid
        expect(described_class.new(source_location: source_location, destination_location: destination_location, stock_movements: stock_movements)).to be_valid
        expect(described_class.new(destination_location: destination_location, stock_movements: stock_movements)).to be_valid
      end
    end
  end
end
