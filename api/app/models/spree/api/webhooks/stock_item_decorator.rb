module Spree
  module Api
    module Webhooks
      module StockItemDecorator
        def self.prepended(base)
          base.around_save :queue_webhooks_requests_for_variant_backorderable!
        end

        private

        def queue_webhooks_requests_for_variant_backorderable!
          was_out_of_stock = !variant_in_stock?
          was_not_backorderable = !variant_backorderable?
          yield
          touch # changes must be reflected before instantiating the serializer
          return unless emits_webhook_event?(was_not_backorderable, was_out_of_stock)

          variant.queue_webhooks_requests!('variant.backorderable')
        end

        def emits_webhook_event?(was_not_backorderable, was_out_of_stock)
          was_out_of_stock && was_not_backorderable && variant_in_stock? && variant_backorderable?
        end

        # rewriting `variant.in_stock?` as is currently being cached
        def variant_in_stock?
          stock_items.sum(:count_on_hand) > 0
        end

        # rewriting `variant.backorderable?` as is currently being cached
        def variant_backorderable?
          stock_items.any?(&:backorderable)
        end

        def stock_items
          variant.stock_items.with_active_stock_location
        end
      end
    end
  end
end

Spree::StockItem.prepend(Spree::Api::Webhooks::StockItemDecorator)
