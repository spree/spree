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
    # caller rather than from the request, a line may be named more than once
    # to split it, and a record stays receivable until every unit has arrived —
    # each receipt adds to what the earlier ones counted.
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

      def post_sale_lines
        post_sale_record.public_send(:"#{post_sale_kind}_line_items")
      end

      # Approved, or received with units still to come.
      def ensure_receivable
        return if post_sale_record.approved?

        failure(post_sale_record, :not_approved) unless post_sale_record.received?
        failure(post_sale_record, :already_received) if post_sale_lines.all? { |line| line.unreceived_quantity.zero? }
      end

      def normalize_items
        @normalized_items =
          if items.nil?
            post_sale_lines.map { |line| { line: line, quantity: line.unreceived_quantity, resellable: true } }
          else
            items.map { |item| normalize_item(item) }
          end

        failure(post_sale_record, :no_items_received) if @normalized_items.sum { |item| item[:quantity] }.zero?

        @normalized_items.group_by { |item| item[:line] }.each do |line, line_items|
          failure(post_sale_record, :invalid_quantity) if line_items.sum { |item| item[:quantity] } > line.unreceived_quantity
        end
      end

      def normalize_item(item)
        line = item[:"#{post_sale_kind}_line_item"]
        quantity = item[:quantity].to_i

        unless line&.public_send(:"#{post_sale_kind}_id") == post_sale_record.id
          failure(post_sale_record, :"item_not_on_#{post_sale_kind}")
        end
        failure(post_sale_record, :invalid_quantity) if quantity.negative?

        { line: line, quantity: quantity, resellable: item.fetch(:resellable, true) }
      end

      # Adds this receipt to what earlier ones counted. The line is locked and
      # checked again, so two receipts racing cannot count more than came back.
      def record_receipt
        @normalized_items.group_by { |item| item[:line] }.each do |line, line_items|
          line.lock!
          received = line_items.sum { |item| item[:quantity] }
          failure(post_sale_record, :invalid_quantity) if received > line.unreceived_quantity

          received_quantity = line.received_quantity + received
          resellable_quantity = line.resellable_quantity + line_items.select { |item| item[:resellable] }.sum { |item| item[:quantity] }

          line.update!(
            received_quantity: received_quantity,
            resellable_quantity: resellable_quantity,
            resellable: resellable_quantity == received_quantity
          )
        end
      end

      # Only resellable goods go back into sellable stock — a damaged item
      # is received but never restocked.
      def restock_resellable_items
        @normalized_items.select { |item| item[:resellable] }.group_by { |item| item[:line] }.each do |line, line_items|
          quantity = line_items.sum { |item| item[:quantity] }
          next unless quantity.positive?

          post_sale_record.stock_location.restock(restock_variant(line), quantity, post_sale_record)
        end
      end

      # A later receipt leaves the time the first one arrived alone.
      def mark_received
        post_sale_record.update!(status: 'received', received_at: post_sale_record.received_at || Time.current)
      end
    end
  end
end
