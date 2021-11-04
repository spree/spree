require 'spec_helper'

describe Spree::StockItem do
  describe 'sending webhooks' do
    let(:queue_requests) { instance_double(Spree::Webhooks::Subscribers::QueueRequests) }
    let(:store) { create(:store, default: true) }
    let!(:product) { create(:product_in_stock) }
    let(:stock_item) { product.master.stock_items.take }
    let(:body) { Spree::Api::V2::Platform::ProductSerializer.new(product).serializable_hash.to_json }

    describe '#update' do
      context 'when all product variants are tracked' do
        context 'when product total_on_hand is greater than 0' do
          it 'does not emit the product.out_of_stock event' do
            expect { stock_item.adjust_count_on_hand(10) }.not_to emit_webhook_event('product.out_of_stock')
          end
        end

        context 'when product total_on_hand is equal to 0' do
          it 'emits the product.out_of_stock event' do
            expect { stock_item.set_count_on_hand(0) }.to emit_webhook_event('product.out_of_stock')
          end
        end

        context 'when product total_on_hand is less than 0' do
          before { stock_item.update(backorderable: true) }

          it 'emits the product.out_of_stock event' do
            expect { stock_item.set_count_on_hand(-2) }.to emit_webhook_event('product.out_of_stock')
          end
        end
      end

      context 'when some of product variants is not tracked' do
        before { product.master.update(track_inventory: false) }

        context 'when product total_on_hand is greater than 0' do
          it 'does not emit the product.out_of_stock event' do
            expect { stock_item.adjust_count_on_hand(10) }.not_to emit_webhook_event('product.out_of_stock')
          end
        end

        context 'when product total_on_hand is equal to 0' do
          it 'does not emit the product.out_of_stock event' do
            expect { stock_item.adjust_count_on_hand(0) }.not_to emit_webhook_event('product.out_of_stock')
          end
        end

        context 'when product total_on_hand is less than 0' do
          it 'does not emit the product.out_of_stock event' do
            expect { stock_item.adjust_count_on_hand(-10) }.not_to emit_webhook_event('product.out_of_stock')
          end
        end
      end
    end

    describe '#destroy' do
      let!(:second_variant) do
        variant = create(:variant, product: product)
        variant.stock_items.take.set_count_on_hand(10)
        variant
      end

      context 'when all product variants are tracked' do
        context 'when product total_on_hand after deleting some stock item is greater than 0' do
          before { stock_item.adjust_count_on_hand(10) }

          it 'does not emit the product.out_of_stock event' do
            expect { second_variant.stock_items.take.destroy }.not_to emit_webhook_event('product.out_of_stock')
          end
        end

        context 'when product total_on_hand after deleting some stock item is equal to 0' do
          before { stock_item.set_count_on_hand(0) }

          it 'emits the product.out_of_stock event' do
            expect { second_variant.stock_items.take.destroy }.to emit_webhook_event('product.out_of_stock')
          end
        end

        context 'when product total_on_hand after deleting some stock item is less than 0' do
          before do
            stock_item.update(backorderable: true)
            stock_item.set_count_on_hand(-5)
          end

          it 'emits the product.out_of_stock event' do
            expect { second_variant.stock_items.take.destroy }.to emit_webhook_event('product.out_of_stock')
          end
        end
      end

      context 'when some of product variants is not tracked' do
        before { product.master.update(track_inventory: false) }

        context 'when product total_on_hand after deleting some stock item is greater than 0' do
          it 'does not emit the product.out_of_stock event' do
            expect { second_variant.stock_items.take.destroy }.not_to emit_webhook_event('product.out_of_stock')
          end
        end

        context 'when product total_on_hand after deleting some stock item is equal to 0' do
          before { stock_item.set_count_on_hand(0) }

          it 'does not emit the product.out_of_stock event' do
            expect { second_variant.stock_items.take.destroy }.not_to emit_webhook_event('product.out_of_stock')
          end
        end

        context 'when product total_on_hand after deleting some stock item is less than 0' do
          before do
            stock_item.update(backorderable: true)
            stock_item.set_count_on_hand(-5)
          end

          it 'does not emit the product.out_of_stock event' do
            expect { second_variant.stock_items.take.destroy }.not_to emit_webhook_event('product.out_of_stock')
          end
        end
      end

      context 'when there are no stock items left' do
        it 'emits the product.out_of_stock event' do
          expect { stock_item.destroy }.to emit_webhook_event('product.out_of_stock')
        end
      end
    end
  end
end
