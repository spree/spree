module Spree
  module Api
    module Webhooks
      module StockItemDecorator
        def self.prepended(base)
          base.around_save :queue_webhooks_requests_for_variant_back_in_stock!
          base.around_save :queue_webhooks_requests_for_variant_backorderable!
        end

        private

        def queue_webhooks_requests_for_variant_back_in_stock!
          was_out_of_stock = !variant_in_stock?
          yield
          if was_out_of_stock && variant_in_stock?
            variant.queue_webhooks_requests!('variant.back_in_stock')
          end
        end

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
          Spree::Variant.in_stock.exists?(id: variant.id)
        end

        # rewriting `variant.backorderable?` as is currently being cached
        def variant_backorderable?
          Spree::Variant.backorderable.exists?(id: variant.id)
        end
      end
    end
  end
end

Spree::StockItem.prepend(Spree::Api::Webhooks::StockItemDecorator)
