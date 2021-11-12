module Spree
  module Api
    module Webhooks
      module StockItemDecorator
        def self.prepended(base)
          base.around_save :queue_webhooks_requests_for_variant_backorderable!
        end

        private

        def queue_webhooks_requests_for_variant_backorderable!
          was_out_of_stock = !variant.in_stock_or_backorderable?
          was_not_backorderable = !variant_backorderable?
          yield
          if was_out_of_stock && was_not_backorderable && variant_backorderable?
            reload
            variant.queue_webhooks_requests!('variant.backorderable')
          end
        end

        def variant_backorderable?
          variant.stock_items.exists?(backorderable: true)
        end
      end
    end
  end
end

Spree::StockItem.prepend(Spree::Api::Webhooks::StockItemDecorator)
