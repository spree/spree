module Spree
  module Api
    module Webhooks
      module StockMovementDecorator
        def self.prepended(base)
          base.around_save :queue_webhooks_requests_for_variant_back_in_stock!
        end

        def update_stock_item_quantity
          variant_in_stock_before_update = stock_item.variant.in_stock?
          super
          variant = stock_item.variant
          variant.queue_webhooks_requests!('variant.out_of_stock') if variant_in_stock_before_update && !stock_item.variant.in_stock?
        end

        private

        delegate :id, to: :variant, prefix: true

        def queue_webhooks_requests_for_variant_back_in_stock!
          variant_was_out_of_stock = !variant_in_stock?
          yield
          if variant_was_out_of_stock && variant_in_stock?
            variant.queue_webhooks_requests!('variant.back_in_stock')
          end
        end

        def variant
          stock_item.variant
        end

        def variant_in_stock?
          Spree::Variant.joins(:stock_items).where(id: variant_id).where(<<~SQL).exists?
            #{Spree::StockItem.table_name}.count_on_hand > 0 OR
            #{Spree::Variant.table_name}.track_inventory = FALSE OR
            #{Spree::StockItem.table_name}.backorderable = TRUE
          SQL
        end
      end
    end
  end
end

Spree::StockMovement.prepend(Spree::Api::Webhooks::StockMovementDecorator)
