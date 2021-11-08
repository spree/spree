module Spree
  module Api
    module Webhooks
      module StockItemDecorator
        def self.prepended(base)
          base.after_commit :queue_webhooks_requests_for_sold_out_products
        end

        private

        def queue_webhooks_requests_for_sold_out_products
          return if deleted_at.nil? && !count_on_hand_previously_changed?
          return if product_in_stock? || non_tracked_variant_exists?

          product.queue_webhooks_requests!('product.out_of_stock')
        end

        def product_in_stock?
          product.stock_items.where('count_on_hand > 0 OR backorderable = TRUE').exists?
        end

        def non_tracked_variant_exists?
          product.variants_including_master.where(track_inventory: false).exists?
        end
      end
    end
  end
end

Spree::StockItem.prepend(Spree::Api::Webhooks::StockItemDecorator)
