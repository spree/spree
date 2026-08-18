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
    let(:stock_level) { source_location.stock_levels.order(:id).first }
    let(:variant) { stock_level.variant }

    it_behaves_like 'metadata'
    it_behaves_like 'lifecycle events'

    describe '#reference' do
      subject { stock_transfer.reference }

      it { is_expected.to eq 'PO123' }
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

      # A transfer moves goods, not promises: units another order is waiting
      # for stay promised at the source.
      it 'leaves the source location\'s promises intact' do
        level = source_location.stock_level_or_create(variant)
        level.update_column(:allocated_count, 3)

        subject

        expect(level.reload.allocated_count).to eq(3)
      end

      it 'transfers variants between 2 locations' do
        subject

        expect(source_location.count_on_hand(variant)).to eq 5
        expect(destination_location.count_on_hand(variant)).to eq 5

        expect(stock_transfer.source_location).to eq source_location
        expect(stock_transfer.destination_location).to eq destination_location

        # Quantities are positive on both sides now; the kind says which way
        # the goods went.
        expect(stock_transfer.source_movements.first).to have_attributes(quantity: 5, kind: 'shipped')
        expect(stock_transfer.destination_movements.first).to have_attributes(quantity: 5, kind: 'received')
        expect(stock_transfer.source_movements.first.stock_transfer).to eq(stock_transfer)
      end

      # Checking only for a positive balance let a transfer take more than the
      # shelf held and leave it negative.
      context 'when the source holds some of the variant but not enough' do
        let(:variants) { { variant => 5 } }

        before { source_location.stock_level_or_create(variant).update_column(:count_on_hand, 1) }

        it 'does not transfer the variants' do
          expect(subject).to be false
          expect(stock_transfer.errors[:base]).to include(Spree.t('stock_transfer.errors.variants_unavailable'))
        end

        it 'leaves the source shelf alone' do
          subject

          expect(source_location.stock_level(variant).reload.count_on_hand).to eq(1)
        end
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

      it 'receives new inventory (from a seller)' do
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
