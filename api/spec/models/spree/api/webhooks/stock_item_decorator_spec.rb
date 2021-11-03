require 'spec_helper'

describe Spree::StockItem do
  describe 'sending webhooks' do
    let(:queue_requests) { instance_double(Spree::Webhooks::Subscribers::QueueRequests) }
    let(:store) { create(:store, default: true) }
    let(:body) { Spree::Api::V2::Platform::ProductSerializer.new(product).serializable_hash.to_json }
    let!(:product) { create(:product_in_stock) }

    before do
      ENV['DISABLE_SPREE_WEBHOOKS'] = nil
      allow(Spree::Webhooks::Subscribers::QueueRequests).to receive(:new).and_return(queue_requests)
      allow(queue_requests).to receive(:call).with(any_args)
    end

    after { ENV['DISABLE_SPREE_WEBHOOKS'] = 'true' }

    shared_examples 'does not execute QueueRequests.call' do
      it 'does not execute QueueRequests.call' do
        expect(queue_requests).not_to have_received(:call).with(event: 'product.out_of_stock', body: body)
      end
    end

    subject :stock_item do
      stock_item = product.master.stock_items.take
      stock_item.update(backorderable: true)
      stock_item
    end

    describe '#update' do
      context 'when all product variants are tracked' do
        context 'when product total_on_hand is greater than 0' do
          it_behaves_like 'does not execute QueueRequests.call'
        end

        context 'when product total_on_hand is equal to 0' do
          before { stock_item.set_count_on_hand(0) }

          it 'executes QueueRequests.call' do
            expect(queue_requests).to have_received(:call).with(event: 'product.out_of_stock', body: body).once
          end
        end

        context 'when product total_on_hand is less than 0' do
          before { stock_item.set_count_on_hand(-2) }

          it 'executes QueueRequests.call' do
            expect(queue_requests).to have_received(:call).with(event: 'product.out_of_stock', body: body).once
          end
        end
      end

      context 'when some of product variants is not tracked' do
        before { product.master.update(track_inventory: false) }

        context 'when product total_on_hand is greater than 0' do
          it_behaves_like 'does not execute QueueRequests.call'
        end

        context 'when product total_on_hand is equal to 0' do
          before { stock_item.set_count_on_hand(0) }

          it_behaves_like 'does not execute QueueRequests.call'
        end

        context 'when product total_on_hand is less than 0' do
          before { stock_item.set_count_on_hand(-2) }

          it_behaves_like 'does not execute QueueRequests.call'
        end
      end

      context 'when product has only default master variant stock item' do
        it_behaves_like 'does not execute QueueRequests.call'
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
          before do
            second_variant.stock_items.take.destroy!
            second_variant.stock_items.reload
          end

          it_behaves_like 'does not execute QueueRequests.call'
        end

        context 'when product total_on_hand after deleting some stock item is equal to 0' do
          before do
            stock_item.set_count_on_hand(0)
            second_variant.stock_items.take.destroy!
            second_variant.stock_items.reload
          end

          it 'executes QueueRequests.call' do
            expect(queue_requests).to have_received(:call).with(event: 'product.out_of_stock', body: body).once
          end
        end

        context 'when product total_on_hand after deleting some stock item is less than 0' do
          before do
            stock_item.set_count_on_hand(-5)
            second_variant.stock_items.take.destroy!
            second_variant.stock_items.reload
          end

          it 'executes QueueRequests.call' do
            expect(queue_requests).to have_received(:call).with(event: 'product.out_of_stock', body: body).once
          end
        end
      end

      context 'when some of product variants is not tracked' do
        before { product.master.update(track_inventory: false) }

        context 'when product total_on_hand after deleting some stock item is greater than 0' do
          before do
            second_variant.stock_items.take.destroy!
            second_variant.stock_items.reload
          end

          it_behaves_like 'does not execute QueueRequests.call'
        end

        context 'when product total_on_hand after deleting some stock item is equal to 0' do
          before do
            stock_item.set_count_on_hand(0)
            second_variant.stock_items.take.destroy!
            second_variant.stock_items.reload
          end

          it_behaves_like 'does not execute QueueRequests.call'
        end

        context 'when product total_on_hand after deleting some stock item is less than 0' do
          before do
            stock_item.set_count_on_hand(-5)
            second_variant.stock_items.take.destroy!
            second_variant.stock_items.reload
          end

          it_behaves_like 'does not execute QueueRequests.call'
        end
      end

      context 'when destroyed StockItem was the last one' do
        before { Spree::StockItem.destroy_all }

        it 'executes QueueRequests.call' do
          expect(queue_requests).to have_received(:call).with(event: 'product.out_of_stock', body: body).once
        end
      end
    end
  end
end
