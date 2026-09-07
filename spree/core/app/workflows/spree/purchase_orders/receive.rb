module Spree
  module PurchaseOrders
    # Books in what the supplier actually delivered.
    #
    # This is the moment purchased goods first exist as far as availability is
    # concerned: nothing before it touched `count_on_hand`, because a merchant
    # who has ordered stock does not have it. Suppliers under-ship and
    # back-order routinely, so `quantity_received` is the running total for the
    # line and only the difference from last time reaches the shelf.
    #
    # Each `received` movement carries the line's `unit_cost`, which is what a
    # rolling average cost is computed from — including across two partial
    # deliveries agreed at different prices.
    class Receive < Spree::Workflow
      hooks :validate, :before_restock, :after_receive

      # @param purchase_order [Spree::PurchaseOrder]
      # @param items [Array<Hash>, nil] `[{ item:, quantity_received: }]`;
      #   nil receives every line in full
      # @param received_by [Object, nil]
      def perform(purchase_order:, items: nil, received_by: nil)
        super

        step :ensure_receivable
        step :normalize_items
        run_hooks :validate

        ApplicationRecord.transaction do
          step :record_receipt
          run_hooks :before_restock
          step :restock_deltas
          step :settle_status
        end

        run_hooks :after_receive
        purchase_order.publish_event("purchase_order.#{purchase_order.status}")
        success(purchase_order.reload)
      end

      private

      def ensure_receivable
        return if purchase_order.ordered? || purchase_order.partially_received?

        failure(purchase_order, Spree.t('purchase_order.errors.not_ordered'))
      end

      def normalize_items
        @normalized_items =
          if items.nil?
            purchase_order.items.map do |line|
              { item: line, quantity_received: line.quantity_ordered, delta: line.outstanding }
            end
          else
            Array(items).map { |item| normalize_item(item) }
          end

        return if @normalized_items.any? { |item| item[:delta].positive? }

        failure(purchase_order, Spree.t('purchase_order.errors.no_items_received'))
      end

      # The running total may only go up: taking units back off the shelf is a
      # correction, which is what a manual adjustment is for.
      def normalize_item(item)
        line = item[:item]
        failure(purchase_order, Spree.t('purchase_order.errors.item_not_on_order')) unless
          line&.purchase_order_id == purchase_order.id

        quantity = item[:quantity_received].to_i
        if quantity.negative? || quantity > line.quantity_ordered || quantity < line.quantity_received
          failure(purchase_order, Spree.t('purchase_order.errors.invalid_received_quantity',
                                          variant: line.variant_name, ordered: line.quantity_ordered))
        end

        { item: line, quantity_received: quantity, delta: quantity - line.quantity_received.to_i }
      end

      def record_receipt
        @normalized_items.each do |item|
          item[:item].update!(quantity_received: item[:quantity_received])
        end
      end

      def restock_deltas
        destination = purchase_order.destination_location

        @normalized_items.each do |item|
          next unless item[:delta].positive?

          destination.restock(item[:item].variant, item[:delta], purchase_order,
                              unit_cost: item[:item].unit_cost)
        end
      end

      def settle_status
        # The caller's lines are freshly-loaded instances, not the ones the
        # association is holding, so the totals have to be re-read before they
        # can decide the status.
        purchase_order.items.reset
        status = purchase_order.status_after_receive
        attributes = { status: status }
        attributes[:received_at] = Time.current if status == 'received'

        failure(purchase_order) unless purchase_order.update(attributes)
      end
    end
  end
end
