require 'spec_helper'

describe Spree::StockMovement do
  let(:stock_item) { create(:stock_item) }
  let(:variant) { stock_item.variant }
  let(:stock_movement) { create(:stock_movement, stock_item: stock_item, quantity: movement_quantity) }
  let(:body) { Spree::Api::V2::Platform::VariantSerializer.new(variant).serializable_hash.to_json }

  describe '#update_stock_item_quantity' do
    subject { stock_movement }

    describe 'when the variant goes out of stock' do
      let(:movement_quantity) { -stock_item.count_on_hand }

      context 'when it is backorderable' do

        it 'does not emit the variant.out_of_stock event' do
          expect { subject }.not_to emit_webhook_event('variant.out_of_stock')
        end
      end

      context 'when it is not backorderable' do
        before { stock_item.update(backorderable: false) }

        it 'emits the variant.out_of_stock event' do
          expect { subject }.to emit_webhook_event('variant.out_of_stock')
        end
      end
    end

    describe 'when the variant does not go out of stock' do
      let(:movement_quantity) { -stock_item.count_on_hand + 1 }

      it 'does not emit the variant.out_of_stock event' do
        expect { subject }.not_to emit_webhook_event('variant.out_of_stock')
      end
    end

    describe 'when the variant was out of stock before the update and after the update' do
      before do
        stock_item.set_count_on_hand(0)
      end

      let(:movement_quantity) { 0 }

      it 'does not emit the variant.out_of_stock event' do
        expect { subject }.not_to emit_webhook_event('variant.out_of_stock')
      end
    end

    describe 'when the inventory is not tracked' do
      before do
        variant.update(track_inventory: false)
        stock_item.update(backorderable: false)
      end

      let(:movement_quantity) { -stock_item.count_on_hand }

      context 'when it goes out of stock and is not backorderable' do
        it 'does not emit the variant.out_of_stock event (the count on hand is not adjusted)' do
          expect { subject }.not_to emit_webhook_event('variant.out_of_stock')
        end
      end
    end
  end
end
