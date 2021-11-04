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
          return if product.in_stock?

          product.queue_webhooks_requests!('product.out_of_stock')
        end
      end
    end
  end
end

Spree::StockItem.prepend(Spree::Api::Webhooks::StockItemDecorator)
