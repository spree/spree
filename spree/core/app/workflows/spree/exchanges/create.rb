module Spree
  module Exchanges
    # Opens an exchange request: items coming back, and what should go out
    # in their place.
    class Create < Spree::Workflow
      hooks :validate, :after_create

      attr_reader :exchange

      # @param order [Spree::Order]
      # @param items [Array<Hash>] `[{ fulfillment_item:, new_variant:, quantity: }]`
      # @param stock_location [Spree::StockLocation, nil]
      # @param reason [Spree::ReturnReason, nil]
      # @param memo [String, nil]
      # @param created_by [Object, nil] nil for customer self-service
      def perform(order:, items:, stock_location: nil, reason: nil, memo: nil, created_by: nil)
        super

        step :ensure_exchangeable
        step :normalize_items
        run_hooks :validate

        ApplicationRecord.transaction do
          step :build_exchange
        end

        run_hooks :after_create
        exchange.publish_event('exchange.requested')
        success(exchange.reload)
      end

      private

      def ensure_exchangeable
        failure(order, :order_not_completed) unless order.completed?
        failure(order, :order_canceled) if order.canceled?
        failure(order, :no_items_to_exchange) if items.blank?
      end

      def normalize_items
        @normalized_items = items.map do |item|
          fulfillment_item = item[:fulfillment_item]
          new_variant = item[:new_variant]
          quantity = item[:quantity].to_i

          failure(order, :invalid_quantity) unless quantity.positive?
          failure(order, :item_not_on_order) unless fulfillment_item&.order_id == order.id
          failure(order, :replacement_required) if new_variant.blank?

          # A replacement nobody can ship is not an exchange the merchant can
          # honour — catch it now rather than at fulfillment time.
          unless new_variant.purchasable?
            failure(order, "#{new_variant.name} is not available")
          end

          { fulfillment_item: fulfillment_item, new_variant: new_variant, quantity: quantity }
        end
      end

      def build_exchange
        @exchange = order.exchanges.new(
          store: order.store,
          stock_location: stock_location || default_stock_location,
          reason: reason,
          memo: memo,
          created_by: created_by,
          status: Spree::Exchange.default_status
        )

        @normalized_items.each do |item|
          fulfillment_item = item[:fulfillment_item]
          @exchange.exchange_line_items.build(
            fulfillment_item: fulfillment_item,
            line_item: fulfillment_item.line_item,
            original_variant: fulfillment_item.variant,
            new_variant: item[:new_variant],
            quantity: item[:quantity]
          )
        end

        failure(@exchange) unless @exchange.save
      end

      def default_stock_location
        @normalized_items.first[:fulfillment_item].fulfillment&.stock_location ||
          order.store.stock_locations.first
      end
    end
  end
end
