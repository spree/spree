module Spree
  module Api
    module Webhooks
      module StockItemDecorator
        def self.prepended(base)
          base.around_create :queue_webhooks_requests_for_variant_backorderable_on_create!
          base.around_update :queue_webhooks_requests_for_variant_backorderable_on_update!
        end

        private

        def queue_webhooks_requests_for_variant_backorderable_on_create!
          was_out_of_stock = variant.out_of_stock?
          yield
          return unless emits_webhook_event_on_create?(variant.reload, was_out_of_stock)

          variant.queue_webhooks_requests!('variant.backorderable') 
        end

        def emits_webhook_event_on_create?(variant, was_out_of_stock)
          was_out_of_stock && variant.in_stock? &&
            # rewritting `variant.backorderable?` as is currently being cached
            variant.stock_items.with_active_stock_location.any?(&:backorderable)
        end

        def queue_webhooks_requests_for_variant_backorderable_on_update!
          was_out_of_stock = variant.out_of_stock?
          was_not_orderable = !variant.backorderable?
          yield
          variant.reload
          variant.touch # changes must be reflected before instantiating the serializer
          return unless emits_webhook_event_on_update?(variant, was_out_of_stock, was_not_orderable)

          variant.queue_webhooks_requests!('variant.backorderable')
        end

        def emits_webhook_event_on_update?(variant, was_out_of_stock, was_not_orderable)
          was_out_of_stock && was_not_orderable && variant.in_stock? && variant.backorderable?
        end
      end
    end
  end
end

Spree::StockItem.prepend(Spree::Api::Webhooks::StockItemDecorator)
