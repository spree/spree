require 'spec_helper'

module Spree
  describe StockLocations::StockItems::Create do
    subject { described_class }

    let!(:stock_location) { create(:stock_location_with_items) }
    let!(:unrelated_variant) { create(:variant) }
    let(:result) { subject.call(stock_location: stock_location) }
    let(:stock_location_class) { stock_location.class }

    describe '#call' do
      context 'Rails < 6', if: Rails::VERSION::MAJOR < 6 do
        context 'with variants to propagate' do
          before { stock_location.stock_items.delete_all }

          it 'propagates the variants' do
            expect { result }.to change { stock_location.stock_items.count }.from(0).to(4)
          end
        end

        context 'without variants to propagate' do
          before { Variant.destroy_all }

          it 'does not propagate stock location variants' do
            expect(stock_location).not_to receive(:propagate_variant)
            result
          end
        end
      end

      context 'Rails >= 6', if: Rails::VERSION::MAJOR >= 6 do
        before do
          # Delete all stock_location.stock_items to start counting from 0.
          stock_location.stock_items.unscope(:where).delete_all
        end

        let(:time_current) { Time.local(1990) }

        context 'with prepared stock items' do
          context 'with duplicate stock items by stock_location_id and variant' do
            it 'removes duplicate stock_items before inserting to avoid duplicate ones' do
              # Make a call of Spree::Variant to obtain the ids, return duplicated records.
              expect(Spree::Variant).to receive(:ids).and_return([1, 1])
              expect { result }.to change { stock_location.stock_items.count }.from(0).to(1)
            end
          end

          context 'without duplicate stock items to insert' do
            let(:created_stock_item) { stock_location.stock_items.order(:id).last }
            let(:created_stock_item_attrs) do
              created_stock_item.attributes.values_at(
                'stock_location_id', 'variant_id', 'backorderable', 'created_at', 'updated_at'
              )
            end

            it 'inserts the stock location stock items' do
              expect { result }.to change { stock_location.stock_items.count }.from(0).to(4)
            end

            it 'sets the stock location data necessary for the inserted stock items' do
              Timecop.freeze(time_current)
              result
              expect(created_stock_item_attrs).to(
                eq([
                  stock_location.id,
                  unrelated_variant.id,
                  stock_location.backorderable_default,
                  time_current,
                  time_current
                ])
              )
              Timecop.return
            end

            it 'invalidates the Variant cache' do
              expect(Spree::Variant).to receive(:touch_all).once
              result
            end
          end
        end

        context 'without prepared stock items' do
          before { Spree::Variant.destroy_all }

          it 'does not insert stock items' do
            expect(stock_location.stock_items).not_to receive(:insert_all)
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
end
