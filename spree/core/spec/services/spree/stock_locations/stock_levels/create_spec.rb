require 'spec_helper'

module Spree
  describe StockLocations::StockLevels::Create do
    subject { described_class }

    let!(:stock_location) { create(:stock_location_with_items) }
    let!(:unrelated_variant) { create(:variant) }
    let(:result) { subject.call(stock_location: stock_location) }
    let(:stock_location_class) { stock_location.class }

    describe '#call' do
      let(:time_current) { Time.local(1990) }

      context 'with prepared stock levels' do
        context 'with stock levels in the db' do
          before { Spree::StockLevel.find(Spree::StockLevel.ids.sample).delete }

          it 'inserts stock levels without duplicates' do
            expect { result }.to change { stock_location.stock_levels.count }.by(1)
            expect(stock_location.stock_levels.count).to eq(Spree::Variant.count)
          end
        end

        context 'without stock levels in the db' do
          before do
            # Delete all stock_location.stock_levels to start counting from 0.
            stock_location.stock_levels.unscope(:where).delete_all
          end

          let(:created_stock_level) { stock_location.stock_levels.find_by(variant_id: unrelated_variant.id) }
          let(:created_stock_level_attrs) do
            created_stock_level.attributes.values_at(
              'stock_location_id', 'variant_id', 'backorderable', 'created_at', 'updated_at'
            )
          end

          it 'inserts the stock location stock levels' do
            expect { result }.to change { stock_location.stock_levels.count }.from(0).to(4)
          end

          it 'sets the stock location data necessary for the inserted stock levels' do
            Timecop.freeze(time_current) do
              result
              expect(created_stock_level_attrs).to(
                eq([
                     stock_location.id,
                     unrelated_variant.id,
                     stock_location.backorderable_default,
                     time_current,
                     time_current
                   ])
              )
            end
          end

          it 'invalidates the Variant cache' do
            expect(Spree::Variant).to receive(:touch_all).once
            result
          end
        end
      end

      context 'without prepared stock levels' do
        before { Spree::Variant.delete_all }

        it 'does not insert stock levels' do
          expect(stock_location.stock_levels).not_to receive(:insert_all)
          result
        end

        it 'does not invalidates the Variant cache' do
          expect(Spree::Variant).not_to receive(:touch_all)
          result
        end
      end
    end
  end
end
