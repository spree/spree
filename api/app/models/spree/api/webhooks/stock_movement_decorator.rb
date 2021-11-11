module Spree
  module Api
    module Webhooks
      module StockMovementDecorator
        def self.prepended(base)
          base.around_save :queue_webhooks_requests_for_variant_back_in_stock!
          base.around_save :queue_webhooks_requests_for_product_back_in_stock!
        end

        # [TODO]: update, this remains as it was
        def update_stock_item_quantity
          variant_in_stock_before_update = stock_item.variant.in_stock?
          super
          variant = stock_item.variant
          variant.queue_webhooks_requests!('variant.out_of_stock') if variant_in_stock_before_update && !stock_item.variant.in_stock?
        end

        private

        delegate :variant, to: :stock_item
        delegate :product, to: :variant

        def queue_webhooks_requests_for_variant_back_in_stock!
          variant_was_out_of_stock = !variant.full_in_stock?
          yield
          if variant_was_out_of_stock && variant.full_in_stock?
            variant.queue_webhooks_requests!('variant.back_in_stock')
          end
        end

        def queue_webhooks_requests_for_product_back_in_stock!
          product_was_out_of_stock = !product_full_in_stock?
          yield
          if product_was_out_of_stock && product_full_in_stock?
            product.queue_webhooks_requests!('product.back_in_stock')
          end
        end

        def product_full_in_stock?
          Spree::Product.joins(:variants).merge(Spree::Variant.full_in_stock).
            exists?(id: product.id)
        end
      end
    end
  end
end

Spree::StockMovement.prepend(Spree::Api::Webhooks::StockMovementDecorator)
