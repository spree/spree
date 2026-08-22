module Spree
  module Returns
    # Opens a return request for fulfilled items on a completed order.
    #
    # The `validate` hook is the seam for return-eligibility policy —
    # 30-day windows, final-sale categories, per-customer-group rules,
    # regional consumer rights. That policy is the most-customized rule in
    # commerce and deliberately does not live in core.
    class Create < Spree::Workflow
      hooks :validate, :after_create

      # The created return — hook handlers read it (nil while :validate runs).
      attr_reader :return_record

      # @param order [Spree::Order] a completed order with fulfilled items
      # @param items [Array<Hash>] `[{ fulfillment_item:, quantity: }]`
      # @param stock_location [Spree::StockLocation, nil] where the goods come
      #   back to; defaults to the location that shipped them
      # @param reason [Spree::ReturnReason, nil]
      # @param memo [String, nil] customer- or staff-supplied note
      # @param created_by [Object, nil] the admin opening it; nil for
      #   customer self-service
      def perform(order:, items:, stock_location: nil, reason: nil, memo: nil, created_by: nil)
        super

        step :ensure_returnable
        step :normalize_items

        # Veto point — return-window and eligibility policy. Before anything
        # is written.
        run_hooks :validate

        ApplicationRecord.transaction do
          step :build_return
        end

        run_hooks :after_create
        return_record.publish_event('return.requested')
        success(return_record.reload)
      end

      private

      def ensure_returnable
        failure(order, :order_not_completed) unless order.completed?
        failure(order, :order_canceled) if order.canceled?
        failure(order, :no_items_to_return) if items.blank?
      end

      # Quantities are validated against what is actually still returnable —
      # units already returned on an earlier request must not come back twice.
      def normalize_items
        @normalized_items = items.map do |item|
          fulfillment_item = item[:fulfillment_item]
          quantity = item[:quantity].to_i

          failure(order, :invalid_quantity) unless quantity.positive?
          failure(order, :item_not_on_order) unless fulfillment_item&.order_id == order.id

          available = returnable_quantity_for(fulfillment_item)
          if quantity > available
            failure(order, "Only #{available} of #{fulfillment_item.variant.name} can be returned")
          end

          { fulfillment_item: fulfillment_item, quantity: quantity }
        end
      end

      def returnable_quantity_for(fulfillment_item)
        already_requested = Spree::ReturnLineItem.
          joins(:return).
          where(fulfillment_item_id: fulfillment_item.id).
          where.not(spree_returns: { status: 'canceled' }).
          sum(:quantity)

        fulfillment_item.quantity.to_i - already_requested
      end

      def build_return
        @return_record = order.returns.new(
          store: order.store,
          stock_location: stock_location || default_stock_location,
          reason: reason,
          memo: memo,
          created_by: created_by,
          status: Spree::Return.default_status
        )

        @normalized_items.each do |item|
          fulfillment_item = item[:fulfillment_item]
          @return_record.return_line_items.build(
            fulfillment_item: fulfillment_item,
            line_item: fulfillment_item.line_item,
            variant: fulfillment_item.variant,
            quantity: item[:quantity]
          )
        end

        failure(@return_record) unless @return_record.save
      end

      # Where the goods should physically come back to.
      #
      # The fulfillment's own location is the best answer — it is where they
      # left from. Failing that, the seller of the items being returned, read
      # off the line item rather than the order: `Order` carries no seller of
      # its own, and after the marketplace split every line on one order
      # belongs to the same seller anyway.
      def default_stock_location
        @normalized_items.first[:fulfillment_item].fulfillment&.stock_location ||
          seller_returns_location ||
          order.store.default_stock_location
      end

      def seller_returns_location
        @normalized_items.
          filter_map { |item| item[:fulfillment_item].line_item&.seller }.
          first&.returns_location
      end
    end
  end
end
