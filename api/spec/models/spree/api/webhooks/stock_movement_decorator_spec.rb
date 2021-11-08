require 'spec_helper'

describe Spree::Api::Webhooks::StockMovementDecorator do
  let(:stock_item) { create(:stock_item) }
  let(:stock_location) { variant.stock_locations.first }
  let(:stock_movement) { create(:stock_movement, stock_item: stock_item, quantity: movement_quantity) }
  let(:body) { Spree::Api::V2::Platform::VariantSerializer.new(variant).serializable_hash.to_json }

  let!(:images) { create_list(:image, 2) }

  describe 'emitting variant.back_in_stock' do
    let(:variant) { create(:variant, track_inventory: true) }

    context 'when stock item was out of stock' do
      context 'when variant changes to be in stock' do
        it do
          expect do
            Timecop.freeze do
              variant.stock_items.update_all(backorderable: false)
              stock_location.stock_movements.new.tap do |stock_movement|
                stock_movement.quantity = 1 # does make it to be in stock
                stock_movement.stock_item = stock_location.set_up_stock_item(variant)
                stock_movement.save
              end
            end
          end.to emit_webhook_event('variant.back_in_stock')
        end
      end

      context 'when variant does not change to be in stock' do
        it do
          expect do
            Timecop.freeze do
              variant.stock_items.update_all(backorderable: false)
              stock_location.stock_movements.new.tap do |stock_movement|
                stock_movement.quantity = 0 # does not make it to be in stock
                stock_movement.stock_item = stock_location.set_up_stock_item(variant)
                stock_movement.save
              end
            end
          end.not_to emit_webhook_event('variant.back_in_stock')
        end
      end
    end

    context 'when variant was in stock' do
      it do
        expect do
          Timecop.freeze do
            # make in_stock? return false based on track_inventory, the easiest case
            variant.update(track_inventory: false)
            stock_location.stock_movements.new.tap do |stock_movement|
              stock_movement.quantity = 2
              stock_movement.stock_item = stock_location.set_up_stock_item(variant)
              stock_movement.save
            end
          end
        end.not_to emit_webhook_event('variant.back_in_stock')
      end
    end
  end

  describe '#update_stock_item_quantity' do
    subject { stock_movement }

    let(:variant) { stock_item.variant }

    describe 'when the variant goes out of stock' do
      let(:movement_quantity) { -stock_item.count_on_hand }

      it 'emits the variant.out_of_stock event' do
        expect { subject }.to emit_webhook_event('variant.out_of_stock')
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
  end
end
