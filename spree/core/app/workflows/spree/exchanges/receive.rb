module Spree
  module Exchanges
    # Records what came back. Same partial-receipt shape as returns: the
    # warehouse enters actual quantities and flags anything unsellable.
    class Receive < Spree::Workflow
      hooks :validate, :before_restock, :after_receive

      # @param exchange [Spree::Exchange]
      # @param items [Array<Hash>, nil] `[{ exchange_line_item:, quantity:, resellable: }]`
      # @param received_by [Object, nil]
      def perform(exchange:, items: nil, received_by: nil)
        super

        step :ensure_receivable
        step :normalize_items
        run_hooks :validate

        ApplicationRecord.transaction do
          step :record_receipt
          run_hooks :before_restock
          step :restock_resellable_items
          step :mark_received
        end

        run_hooks :after_receive
        exchange.publish_event('exchange.received')
        success(exchange.reload)
      end

      private

      def ensure_receivable
        failure(exchange, :not_approved) unless exchange.approved?
      end

      def normalize_items
        @normalized_items =
          if items.nil?
            exchange.exchange_line_items.map do |line|
              { exchange_line_item: line, quantity: line.quantity, resellable: true }
            end
          else
            items.map { |item| normalize_item(item) }
          end

        failure(exchange, :no_items_received) if @normalized_items.sum { |item| item[:quantity] }.zero?
      end

      def normalize_item(item)
        line = item[:exchange_line_item]
        quantity = item[:quantity].to_i

        failure(exchange, :item_not_on_exchange) unless line&.exchange_id == exchange.id
        failure(exchange, :invalid_quantity) if quantity.negative? || quantity > line.quantity

        { exchange_line_item: line, quantity: quantity, resellable: item.fetch(:resellable, true) }
      end

      def record_receipt
        @normalized_items.each do |item|
          item[:exchange_line_item].update!(
            received_quantity: item[:quantity],
            resellable: item[:resellable]
          )
        end
      end

      def restock_resellable_items
        @normalized_items.each do |item|
          next unless item[:resellable]
          next unless item[:quantity].positive?

          exchange.stock_location.restock(
            item[:exchange_line_item].original_variant,
            item[:quantity],
            exchange
          )
        end
      end

      def mark_received
        exchange.update!(status: 'received', received_at: Time.current)
      end
    end
  end
end
