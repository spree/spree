module Spree
  module Api
    module Webhooks
      module StockMovementDecorator
        def update_stock_item_quantity
          super
          variant = stock_item.variant
          variant.queue_webhooks_requests!('variant.out_of_stock') unless variant.in_stock?
        end
      end
    end
  end
end

Spree::StockMovement.prepend(Spree::Api::Webhooks::StockMovementDecorator)
