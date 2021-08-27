require 'spec_helper'

module Spree
  describe StockLocations::StockItems::Create do
    subject { described_class }

    let!(:stock_location) { create :stock_location_with_items }
    let!(:unrelated_variant) { create(:variant) }
    let(:result) { subject.call(stock_location: stock_location) }
    let(:stock_location_class) { stock_location.class }

    describe '#call' do
      after { allow(stock_location).to(receive(:class).and_call_original) }

      context 'when Spree::StockLocation does not respond to insert_all' do
        before do
          allow(stock_location_class).to(receive(:method_defined?).with(:insert_all).and_return(false))
          allow(stock_location).to(receive(:class).and_return(stock_location_class))
        end

        context 'with variants to propagate' do
          before { stock_location.stock_items.destroy_all }

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

      context 'when Spree::StockLocation responds to insert_all and touch_all' do
        before do
          allow(stock_location_class).to(receive(:method_defined?).with(:insert_all).and_return(true))
          allow(stock_location_class).to(receive(:method_defined?).with(:touch_all).and_return(true))
          allow(stock_location).to(receive(:class).and_return(stock_location_class))
        end

        context 'with prepared stock items' do
          let(:time_current) { Time.local(1990) }
          let(:created_stock_item) { stock_location.stock_items.order(:id).last }
          let(:created_stock_item_attrs) do
            created_stock_item.attributes.values_at(
              'stock_location_id', 'variant_id', 'backorderable', 'created_at', 'updated_at'
            )
          end

          it 'inserts the stock location stock items' do
            expect { result }.to change { stock_location.stock_items.count }.from(4).to(8)
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
