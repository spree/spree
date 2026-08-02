module Spree
  module Returns
    # Records what the warehouse actually received.
    #
    # Partial and damaged receipt is the normal case, not an edge case: the
    # customer said three items were coming, two arrived, one of those is not
    # resellable. Quantities and resellable flags therefore come from the
    # caller rather than from the request, which is precisely what a state
    # machine transition could not express.
    class Receive < Spree::Workflow
      hooks :validate, :before_restock, :after_receive

      # @param return_record [Spree::Return]
      # @param items [Array<Hash>, nil] `[{ return_line_item:, quantity:,
      #   resellable: }]`; nil receives everything as requested and resellable
      # @param received_by [Object, nil]
      def perform(return_record:, items: nil, received_by: nil)
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
        return_record.publish_event('return.received')
        success(return_record.reload)
      end

      private

      def ensure_receivable
        failure(return_record, :not_approved) unless return_record.approved?
      end

      def normalize_items
        @normalized_items =
          if items.nil?
            return_record.return_line_items.map do |line|
              { return_line_item: line, quantity: line.quantity, resellable: true }
            end
          else
            items.map { |item| normalize_item(item) }
          end

        failure(return_record, :no_items_received) if @normalized_items.sum { |item| item[:quantity] }.zero?
      end

      def normalize_item(item)
        line = item[:return_line_item]
        quantity = item[:quantity].to_i

        failure(return_record, :item_not_on_return) unless line&.return_id == return_record.id
        failure(return_record, :invalid_quantity) if quantity.negative? || quantity > line.quantity

        { return_line_item: line, quantity: quantity, resellable: item.fetch(:resellable, true) }
      end

      def record_receipt
        @normalized_items.each do |item|
          item[:return_line_item].update!(
            received_quantity: item[:quantity],
            resellable: item[:resellable]
          )
        end
      end

      # Only resellable goods go back into sellable stock — a damaged return
      # is received but never restocked.
      def restock_resellable_items
        @normalized_items.each do |item|
          next unless item[:resellable]
          next unless item[:quantity].positive?

          return_record.stock_location.restock(
            item[:return_line_item].variant,
            item[:quantity],
            return_record
          )
        end
      end

      def mark_received
        return_record.update!(status: 'received', received_at: Time.current)
      end
    end
  end
end
