require 'spec_helper'

module Spree
  describe StockLocations::StockItems::Create do
    subject { described_class }

    let!(:stock_location) { create :stock_location_with_items }
    let!(:unrelated_variant) { create(:variant) }
    let(:result) { subject.call(stock_location: stock_location) }
    let(:klass_dbl) { stock_location.class }

    describe '#call' do
      after { allow(stock_location).to(receive(:class).and_call_original) }

      context 'when Spree::StockLocation does not respond to insert_all' do
        before do
          allow(klass_dbl).to(receive(:method_defined?).with(:insert_all).and_return(false))
          allow(stock_location).to(receive(:class).and_return(klass_dbl))
        end

        context 'with variants to propagate' do
          before { unrelated_variant.stock_items.where(id: stock_location.stock_items.ids).destroy_all }

          it 'propagates the variants still not related to the given stock location stock items' do
            expect { result }.to change { stock_location.stock_items.count }.from(3).to(4)
          end

          it 'creates the stock items with the right variant' do
            result
            expect(stock_location.stock_items.order(created_at: :desc).first.variant_id).to eq(unrelated_variant.id)
          end
        end

        context 'without variants to propagate' do
          it 'does not propagate stock location variants' do
            expect(stock_location).not_to receive(:propagate_variant)
            result
          end
        end
      end

      context 'when Spree::StockLocation does not respond to touch_all' do
        before do
          allow(klass_dbl).to(receive(:method_defined?).with(:insert_all).and_return(true))
          allow(klass_dbl).to(receive(:method_defined?).with(:touch_all).and_return(false))
          allow(stock_location).to(receive(:class).and_return(klass_dbl))
          unrelated_variant.stock_items.where(id: stock_location.stock_items.ids).destroy_all
        end

        it 'propagates the variants still not related to the stock items from the stock location' do
          expect { result }.to change { stock_location.stock_items.count }.from(3).to(4)
        end

        it 'creates the stock items with the right variant' do
          result
          expect(stock_location.stock_items.order(created_at: :desc).first.variant_id).to eq(unrelated_variant.id)
        end
      end

      context 'when Spree::StockLocation responds to insert_all and touch_all' do
        before do
          allow(klass_dbl).to(receive(:method_defined?).with(:insert_all).and_return(true))
          allow(klass_dbl).to(receive(:method_defined?).with(:touch_all).and_return(true))
          allow(stock_location).to(receive(:class).and_return(klass_dbl))
        end

        context 'with prepared stock items' do
          let(:time_current) { Time.local(1990) }

          it 'inserts the stock location stock items' do
            expect { result }.to change { stock_location.stock_items.count }.from(4).to(8)
          end

          it 'sets the stock location data necessary for the inserted stock items' do
            Timecop.freeze(time_current)
            result
            expect(stock_location.stock_items.order(:id).last.attributes.values_at('stock_location_id', 'variant_id', 'backorderable', 'created_at', 'updated_at')).to eq([stock_location.id, unrelated_variant.id, stock_location.backorderable_default, time_current, time_current])
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
