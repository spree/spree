module Spree
  module PostSale
    # Records what the warehouse actually received for a return or an
    # exchange. The including workflow names the record (`post_sale_record`);
    # its lines, the item key callers pass (`return_line_item:` or
    # `exchange_line_item:`) and the error codes follow from the record's
    # event prefix. `restock_variant` says which variant a line puts back.
    #
    # Partial and damaged receipt is the normal case, not an edge case: the
    # customer said three items were coming, two arrived, one of those is not
    # resellable. Quantities and resellable flags therefore come from the
    # caller rather than from the request.
    module Receipt
      private

      def receive
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
        post_sale_record.publish_event("#{post_sale_kind}.received")
        success(post_sale_record.reload)
      end

      def post_sale_kind
        post_sale_record.event_prefix
      end

      def restock_variant(line)
        line.variant
      end

      def ensure_receivable
        failure(post_sale_record, :not_approved) unless post_sale_record.approved?
      end

      def normalize_items
        @normalized_items =
          if items.nil?
            post_sale_record.public_send(:"#{post_sale_kind}_line_items").map do |line|
              { line: line, quantity: line.quantity, resellable: true }
            end
          else
            items.map { |item| normalize_item(item) }
          end

        failure(post_sale_record, :no_items_received) if @normalized_items.sum { |item| item[:quantity] }.zero?
      end

      def normalize_item(item)
        line = item[:"#{post_sale_kind}_line_item"]
        quantity = item[:quantity].to_i

        unless line&.public_send(:"#{post_sale_kind}_id") == post_sale_record.id
          failure(post_sale_record, :"item_not_on_#{post_sale_kind}")
        end
        failure(post_sale_record, :invalid_quantity) if quantity.negative? || quantity > line.quantity

        { line: line, quantity: quantity, resellable: item.fetch(:resellable, true) }
      end

      def record_receipt
        @normalized_items.each do |item|
          item[:line].update!(received_quantity: item[:quantity], resellable: item[:resellable])
        end
      end

      # Only resellable goods go back into sellable stock — a damaged item
      # is received but never restocked.
      def restock_resellable_items
        @normalized_items.each do |item|
          next unless item[:resellable]
          next unless item[:quantity].positive?

          post_sale_record.stock_location.restock(restock_variant(item[:line]), item[:quantity], post_sale_record)
        end
      end

      def mark_received
        post_sale_record.update!(status: 'received', received_at: Time.current)
      end
    end
  end
end
