module Spree
  class StockMovement < Spree.base_class
    module Webhooks
      extend ActiveSupport::Concern
      include Spree::Webhooks::HasWebhooks

      included do
        around_save :queue_webhooks_requests_for_variant_out_of_stock!
        around_save :queue_webhooks_requests_for_variant_back_in_stock!
        around_save :queue_webhooks_requests_for_product_out_of_stock!
        around_save :queue_webhooks_requests_for_product_back_in_stock!
      end

      def queue_webhooks_requests_for_variant_out_of_stock!
        variant_in_stock_before_update = variant.in_stock_or_backorderable?
        yield
        if variant_in_stock_before_update && !variant.in_stock_or_backorderable?
          reload
          stock_item.variant.queue_webhooks_requests!('variant.out_of_stock')
        end
      end

      def queue_webhooks_requests_for_variant_back_in_stock!
        variant_was_out_of_stock = !variant.in_stock_or_backorderable?
        yield
        if variant_was_out_of_stock && variant.in_stock_or_backorderable?
          reload
          variant.queue_webhooks_requests!('variant.back_in_stock')
        end
      end

      def queue_webhooks_requests_for_product_back_in_stock!
        product_was_out_of_stock = !product.any_variant_in_stock_or_backorderable?
        yield
        if product_was_out_of_stock && product.any_variant_in_stock_or_backorderable?
          product.queue_webhooks_requests!('product.back_in_stock')
        end
      end

      def queue_webhooks_requests_for_product_out_of_stock!
        product_was_in_stock = product.any_variant_in_stock_or_backorderable?
        yield
        if product_was_in_stock && !product.any_variant_in_stock_or_backorderable?
          product.queue_webhooks_requests!('product.out_of_stock')
        end
      end
    end
  end
end
