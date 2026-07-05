# frozen_string_literal: true

module Spree
  class StockMovement < Spree.base_class
    # Publishes custom stock events when stock levels change.
    #
    # Events:
    # - product.out_of_stock: Product has no stock left for any variant
    # - product.back_in_stock: Product was out of stock and now has stock again
    #
    module CustomEvents
      extend ActiveSupport::Concern

      included do
        around_save :track_stock_changes_for_events
      end

      private

      def track_stock_changes_for_events
        return yield unless Spree::Events.enabled?

        the_product = product
        product_was_in_stock = the_product.any_variant_in_stock_or_backorderable?

        yield

        # Reload to get fresh stock data
        the_product.reload
        product_now_in_stock = the_product.any_variant_in_stock_or_backorderable?

        if product_was_in_stock && !product_now_in_stock
          the_product.publish_event('product.out_of_stock')
        elsif !product_was_in_stock && product_now_in_stock
          the_product.publish_event('product.back_in_stock')
        end
      end

      def product
        stock_item.variant.product
      end
    end
  end
end
