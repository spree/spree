module Spree
  module Carts
    class RemoveOutOfStockItems
      prepend ::Spree::ServiceModule::Base

      def call(cart: nil, order: nil)
        if order
          Spree::Deprecation.warn('Calling Spree::Carts::RemoveOutOfStockItems with order: is deprecated and will be removed in Spree 6.1. Pass cart: instead.')
          cart ||= order
        end
        @messages = []
        @warnings = []

        return success([cart, @messages, @warnings]) if cart.total_quantity.zero? || cart.line_items.none?

        line_items = cart.line_items.includes(variant: [:product, :stock_locations, { stock_items: [:stock_location, :active_stock_reservations] }])

        ActiveRecord::Base.transaction do
          # The predicates record a message per candidate as they run, so the
          # messages exist before the removal is attempted.
          removals = line_items.reject { |line_item| valid_status?(line_item) && stock_available?(line_item) }

          if removals.any?
            workflow = Spree.cart_upsert_items_workflow.new
            workflow.call(
              cart: cart,
              items: removals.map { |line_item| { variant_id: line_item.variant_id, quantity: 0 } }
            )

            # A :validate handler can veto a removal, leaving the line in the
            # cart. Telling the customer it was removed would be a lie, so
            # retract the message for anything that survived.
            discard_messages_for(workflow.warnings)
          end
        end

        if @messages.any? # If any line item was removed, reload the cart
          success([cart.reload, @messages, @warnings])
        else
          success([cart, @messages, @warnings])
        end
      end

      private

      # @param item_warnings [Array<Spree::Carts::ItemWarning>] items the upsert
      #   did not remove
      def discard_messages_for(item_warnings)
        return if item_warnings.empty?

        surviving_variant_ids = item_warnings.filter_map { |warning| warning.variant&.prefixed_id }
        return if surviving_variant_ids.empty?

        retracted = @warnings.select { |warning| surviving_variant_ids.include?(warning[:variant_id]) }
        @messages -= retracted.map { |warning| warning[:message] }
        @warnings -= retracted
      end

      def valid_status?(line_item)
        product = line_item.product
        if !product.active? || product.deleted? || product.discontinued? || line_item.variant.discontinued?
          message = Spree.t('cart_line_item.discontinued', li_name: line_item.name)
          @messages << message
          @warnings << {
            code: 'line_item_removed',
            message: message,
            line_item_id: line_item.prefixed_id,
            variant_id: line_item.variant.prefixed_id
          }
          return false
        end
        true
      end

      def stock_available?(line_item)
        if line_item.insufficient_stock?
          message = Spree.t('cart_line_item.out_of_stock', li_name: line_item.name)
          @messages << message
          @warnings << {
            code: 'line_item_removed',
            message: message,
            line_item_id: line_item.prefixed_id,
            variant_id: line_item.variant.prefixed_id
          }
          return false
        end
        true
      end
    end
  end
end
