require 'spec_helper'

describe Spree::Api::Webhooks::StockItemDecorator do
  let(:body) { Spree::Api::V2::Platform::VariantSerializer.new(variant.reload).serializable_hash.to_json }
  let(:variant) { create(:variant) }
  let(:stock_item) { variant.stock_items.first }
  let(:stock_location) { variant.stock_locations.first }

  describe 'emitting variant.backorderable' do
    context 'when variant was out of stock' do
      before do
        stock_location.stock_movements.new.tap do |stock_movement|
          stock_movement.quantity = 0
          stock_movement.stock_item = stock_location.set_up_stock_item(variant)
          stock_movement.save
        end
      end

      context 'when variant was backorderable' do
        before do
          stock_item.backorderable = true
        end

        it do
          expect do
            Timecop.freeze do
              stock_item.save
            end
          end.not_to emit_webhook_event('variant.backorderable')
        end
      end

      context 'when variant was not backorderable' do
        before { variant.stock_items.update_all(backorderable: false) }

        context 'when variant is not set as backorderable' do
          before do
            stock_item.backorderable = false
          end

          it do
            expect do
              Timecop.freeze do
                stock_item.save
              end
            end.not_to emit_webhook_event('variant.backorderable')
          end
        end

        context 'when variant is set as backorderable' do
          before do
            stock_item.backorderable = true
          end

          it do
            expect do
              Timecop.freeze do
                stock_item.save
              end
            end.to emit_webhook_event('variant.backorderable')
          end
        end
      end
    end

    context 'when variant was not out of stock' do
      before do
        variant.stock_items.update_all(backorderable: false)
        stock_location.stock_movements.new.tap do |stock_movement|
          stock_movement.quantity = 1
          stock_movement.stock_item = stock_location.set_up_stock_item(variant)
          stock_movement.save
        end
        stock_item.backorderable = true
      end

      it do
        expect do
          Timecop.freeze do
            stock_item.save
          end
        end.not_to emit_webhook_event('variant.backorderable')
      end
    end
  end
end
