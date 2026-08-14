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
      subject { described_class.new(stock_level.variant) }

      before(:all) { Spree::StockLocation.delete_all } # FIXME: leaky database

      let!(:stock_location) { create :stock_location_with_items }
      let!(:stock_level) { stock_location.stock_levels.order(:id).first }

      specify { expect(subject.stock_levels).to eq([stock_level]) }
      specify { expect(subject.variant).to eq(stock_level.variant) }

      context 'with a single stock location/item' do
        it 'total_on_hand should match stock_level' do
          expect(subject.total_on_hand).to eq(stock_level.count_on_hand)
        end

        context 'when variant is available' do
          before do
            allow(subject.variant).to receive(:available?).and_return(true)
          end

          context 'when track_inventory_levels is false' do
            before { stub_store_preferences(track_inventory_levels: false) }

            specify { expect(subject.total_on_hand).to eq(Float::INFINITY) }

            it_behaves_like 'unlimited supply'
          end

          context 'when variant inventory tracking is off' do
            before { stock_level.variant.track_inventory = false }

            specify { expect(subject.total_on_hand).to eq(Float::INFINITY) }

            it_behaves_like 'unlimited supply'
          end

          context 'when stock item allows backordering' do
            specify { expect(subject.backorderable?).to be true }

            it_behaves_like 'unlimited supply'
          end

          context 'when stock item prevents backordering' do
            before { stock_level.update(backorderable: false) }

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
        let!(:stock_location_2) { create :stock_location, propagate_all_variants: true }
        let!(:stock_location_3) { create :stock_location, active: false, propagate_all_variants: true }

        before do
          perform_enqueued_jobs(only: Spree::StockLocations::StockLevels::CreateJob)
          stock_location_2.stock_levels.where(variant_id: stock_level.variant).update_all(count_on_hand: 5, backorderable: false)
          stock_location_3.stock_levels.where(variant_id: stock_level.variant).update_all(count_on_hand: 5, backorderable: false)
        end

        it 'total_on_hand should total all active stock_levels' do
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
            before { stock_level.update(backorderable: false) }

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

      context 'with active stock reservations' do
        before { stock_level.update(backorderable: false) }

        let(:other_order) { create(:order) }
        let(:other_line_item) { create(:line_item, order: other_order, variant: stock_level.variant) }

        context 'when stock_reservations_enabled is true' do
          before { stub_store_preferences(stock_reservations_enabled: true) }

          it 'subtracts active reservations from total_on_hand' do
            create(
              :stock_reservation,
              stock_level: stock_level,
              line_item: other_line_item,
              order: other_order,
              quantity: 4,
              expires_at: 5.minutes.from_now
            )
            expect(subject.total_on_hand).to eq(stock_level.count_on_hand - 4)
          end

          it 'ignores expired reservations' do
            create(
              :stock_reservation,
              :expired,
              stock_level: stock_level,
              line_item: other_line_item,
              order: other_order,
              quantity: 4
            )
            expect(subject.total_on_hand).to eq(stock_level.count_on_hand)
          end

          it 'clamps total_on_hand at zero when reservations exceed physical stock' do
            stock_level.set_count_on_hand(2)
            create(
              :stock_reservation,
              stock_level: stock_level,
              line_item: other_line_item,
              order: other_order,
              quantity: 5,
              expires_at: 5.minutes.from_now
            )
            expect(subject.total_on_hand).to eq(0)
          end

          it 'reserved_quantity returns the sum of active reservations' do
            create(
              :stock_reservation,
              stock_level: stock_level,
              line_item: other_line_item,
              order: other_order,
              quantity: 3,
              expires_at: 5.minutes.from_now
            )
            expect(subject.reserved_quantity).to eq(3)
          end

          context 'with an excluded order' do
            subject { described_class.new(stock_level.variant, excluded_order: own_order) }

            let(:own_order) { create(:order) }
            let(:own_line_item) { create(:line_item, order: own_order, variant: stock_level.variant) }

            it "does not count the excluded order's own reservations" do
              create(
                :stock_reservation,
                stock_level: stock_level,
                line_item: own_line_item,
                order: own_order,
                quantity: 4,
                expires_at: 5.minutes.from_now
              )
              expect(subject.reserved_quantity).to eq(0)
              expect(subject.total_on_hand).to eq(stock_level.count_on_hand)
            end

            it "still counts other orders' reservations" do
              create(
                :stock_reservation,
                stock_level: stock_level,
                line_item: own_line_item,
                order: own_order,
                quantity: 4,
                expires_at: 5.minutes.from_now
              )
              create(
                :stock_reservation,
                stock_level: stock_level,
                line_item: other_line_item,
                order: other_order,
                quantity: 2,
                expires_at: 5.minutes.from_now
              )
              expect(subject.reserved_quantity).to eq(2)
            end

            context 'when the excluded order is not yet persisted' do
              subject { described_class.new(stock_level.variant, excluded_order: Spree::Order.new) }

              it 'counts all reservations rather than excluding everything' do
                create(
                  :stock_reservation,
                  stock_level: stock_level,
                  line_item: other_line_item,
                  order: other_order,
                  quantity: 2,
                  expires_at: 5.minutes.from_now
                )
                expect(subject.reserved_quantity).to eq(2)
              end
            end
          end
        end

        context 'when stock_reservations_enabled is false' do
          before { stub_store_preferences(stock_reservations_enabled: false) }

          it 'returns raw count_on_hand even when reservations exist' do
            create(
              :stock_reservation,
              stock_level: stock_level,
              line_item: other_line_item,
              order: other_order,
              quantity: 4,
              expires_at: 5.minutes.from_now
            )
            expect(subject.total_on_hand).to eq(stock_level.count_on_hand)
            expect(subject.reserved_quantity).to eq(0)
          end
        end
      end
    end
  end
end
