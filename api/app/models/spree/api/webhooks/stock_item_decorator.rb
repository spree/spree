module Spree
  module Api
    module Webhooks
      module StockItemDecorator
        def self.prepended(base)
          base.around_save :queue_webhooks_requests_for_variant_backorderable!
          base.around_save :queue_webhooks_requests_for_product_backorderable!
        end

        private

        def queue_webhooks_requests_for_variant_backorderable!
          was_out_of_stock = !variant.full_in_stock?
          was_not_backorderable = !variant_backorderable?
          yield
          if was_out_of_stock && was_not_backorderable && variant_backorderable?
            touch # changes must be reflected before instantiating the serializer
            variant.queue_webhooks_requests!('variant.backorderable')
          end
        end

        def queue_webhooks_requests_for_product_backorderable!
          product_was_out_of_stock = !product_full_in_stock?
          product_was_not_backorderable = !product_backorderable?
          yield
          if product_was_out_of_stock && product_was_not_backorderable && product_backorderable?
            touch
            variant.product.queue_webhooks_requests!('product.backorderable')
          end
        end

        def product_backorderable?
          Spree::StockItem.exists?(backorderable: true, variant_id: variant.product.variants.ids)
        end

        def product_full_in_stock?
          Spree::Product.joins(:variants).merge(Spree::Variant.full_in_stock).
            exists?(id: product.id)
        end

        def variant_backorderable?
          variant.stock_items.exists?(backorderable: true)
        end
      end
    end
  end
end

Spree::StockItem.prepend(Spree::Api::Webhooks::StockItemDecorator)
