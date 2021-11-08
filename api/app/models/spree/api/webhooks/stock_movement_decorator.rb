module Spree
  module Api
    module Webhooks
      module StockMovementDecorator
        def update_stock_item_quantity
          variant_in_stock_before_update = variant_in_stock?
          super
          return if !variant_in_stock_before_update || variant_in_stock?

          stock_item.variant.queue_webhooks_requests!('variant.out_of_stock')
        end

        private

        def variant_in_stock?
          stock_item.variant.stock_items.where('count_on_hand > 0 OR backorderable = TRUE').exists?
        end
      end
    end
  end
end

Spree::StockMovement.prepend(Spree::Api::Webhooks::StockMovementDecorator)
