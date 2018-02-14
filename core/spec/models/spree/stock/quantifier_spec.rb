require 'spec_helper'

shared_examples_for 'unlimited supply' do
  it 'can_supply? any amount' do
    expect(subject.can_supply?(1)).to be true
    expect(subject.can_supply?(101)).to be true
    expect(subject.can_supply?(100_001)).to be true
  end
end

module Spree
  module Stock
    describe Quantifier, type: :model do
      before(:all) { Spree::StockLocation.destroy_all } # FIXME: leaky database

      subject { described_class.new(stock_item.variant) }

      let!(:stock_location) { create :stock_location_with_items }
      let!(:stock_item) { stock_location.stock_items.order(:id).first }

      specify { expect(subject.stock_items).to eq([stock_item]) }
      specify { expect(subject.variant).to eq(stock_item.variant) }

      context 'with a single stock location/item' do
        it 'total_on_hand should match stock_item' do
          expect(subject.total_on_hand).to eq(stock_item.count_on_hand)
        end

        context 'when variant is available' do
          before do
            allow(subject.variant).to receive(:available?).and_return(true)
          end

          context 'when track_inventory_levels is false' do
            before { configure_spree_preferences { |config| config.track_inventory_levels = false } }

            specify { expect(subject.total_on_hand).to eq(Float::INFINITY) }

            it_behaves_like 'unlimited supply'
          end

          context 'when variant inventory tracking is off' do
            before { stock_item.variant.track_inventory = false }

            specify { expect(subject.total_on_hand).to eq(Float::INFINITY) }

            it_behaves_like 'unlimited supply'
          end

          context 'when stock item allows backordering' do
            specify { expect(subject.backorderable?).to be true }

            it_behaves_like 'unlimited supply'
          end

          context 'when stock item prevents backordering' do
            before { stock_item.update_attributes(backorderable: false) }

            specify { expect(subject.backorderable?).to be false }

            it 'can_supply? only upto total_on_hand' do
              expect(subject.can_supply?(1)).to be true
              expect(subject.can_supply?(10)).to be true
              expect(subject.can_supply?(11)).to be false
            end
          end
        end

        context 'when variant is not available' do
          before do
            allow(subject.variant).to receive(:available?).and_return(false)
          end

          it { expect(subject.can_supply?).to be false }
        end
      end

      context 'with multiple stock locations/items' do
        let!(:stock_location_2) { create :stock_location }
        let!(:stock_location_3) { create :stock_location, active: false }

        before do
          stock_location_2.stock_items.where(variant_id: stock_item.variant).update_all(count_on_hand: 5, backorderable: false)
          stock_location_3.stock_items.where(variant_id: stock_item.variant).update_all(count_on_hand: 5, backorderable: false)
        end

        it 'total_on_hand should total all active stock_items' do
          expect(subject.total_on_hand).to eq(15)
        end

        context 'when variant is available' do
          before do
            allow(subject.variant).to receive(:available?).and_return(true)
          end

          context 'when any stock item allows backordering' do
            specify { expect(subject.backorderable?).to be true }

            it_behaves_like 'unlimited supply'
          end

          context 'when all stock items prevent backordering' do
            before { stock_item.update_attributes(backorderable: false) }

            specify { expect(subject.backorderable?).to be false }

            it 'can_supply? upto total_on_hand' do
              expect(subject.can_supply?(1)).to be true
              expect(subject.can_supply?(15)).to be true
              expect(subject.can_supply?(16)).to be false
            end
          end
        end

        context 'when variant is not available' do
          before do
            allow(subject.variant).to receive(:available?).and_return(false)
          end

          it { expect(subject.can_supply?).to be false }
        end
      end
    end
  end
end
