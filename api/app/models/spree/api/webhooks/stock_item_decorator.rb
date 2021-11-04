module Spree
  module Api
    module Webhooks
      module StockItemDecorator
        def self.prepended(base)
          base.after_save :queue_webhooks_requests_for_sold_out_products, if: :saved_changes?
          base.after_destroy :queue_webhooks_requests_for_sold_out_products
        end

        private

        def queue_webhooks_requests_for_sold_out_products
          # binding.pry
          product.queue_webhooks_requests!('product.out_of_stock') unless product.in_stock?
        end
      end
    end
  end
end

Spree::StockItem.prepend(Spree::Api::Webhooks::StockItemDecorator)
