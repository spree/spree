module Spree
  module StockReceipts
    # The steps every delivery takes, whichever document it is against. The
    # workflow including this names the document (`receivable`), says when it
    # may be received (`ensure_receivable`), which lines are its own
    # (`line_belongs?`) and what a line's units cost (`unit_cost_for`).
    #
    # Quantities are this delivery's counts, not running totals: "forty
    # arrived, two of them crushed" is what the dock writes down, and what a
    # second delivery of the same line adds to rather than restates. Accepted
    # units reach the shelf; rejected ones exist only on the receipt.
    module Recording
      private

      def record_delivery
        # One delivery at a time per document. Each line's running total is
        # read and then written, so two deliveries booked at once would both
        # add to the same starting figure. The lock also opens the transaction
        # the writes need, and is always taken document-then-level, never the
        # other way, so it cannot cross with the lock
        # `StockLevel#adjust_count_on_hand` takes underneath.
        receivable.with_lock do
          # The caller resolved these before the lock, so their running totals
          # may predate a delivery that has since committed.
          items&.each { |item| item[:item]&.reload }

          step :ensure_receivable
          step :normalize_items
          run_hooks :validate

          step :build_receipt
          step :update_lines
          run_hooks :before_restock
          step :restock_accepted
          step :settle_status
        end

        run_hooks :after_receive
        receivable.publish_event("#{event_prefix}.#{receivable.status}")
        success(stock_receipt.reload)
      end

      # Nothing named means the whole outstanding balance arrived intact.
      def normalize_items
        @normalized_items =
          if items.nil?
            receivable.items.select { |line| line.outstanding.positive? }.map do |line|
              { line: line, quantity_accepted: line.outstanding, quantity_rejected: 0 }
            end
          else
            reject_repeated_lines
            Array(items).filter_map { |item| normalize_item(item) }
          end

        return if @normalized_items.any?

        failure(receivable, Spree.t("#{error_scope}.errors.no_items_received"))
      end

      # A line the payload names but counts nothing on is left out rather than
      # refused: a receive screen submits every row, most of them untouched.
      def normalize_item(item)
        line = item[:item]
        failure(receivable, Spree.t("#{error_scope}.errors.item_not_on_document")) unless line_belongs?(line)

        accepted = item[:quantity_accepted].to_i
        rejected = item[:quantity_rejected].to_i
        if accepted.negative? || rejected.negative?
          failure(receivable, Spree.t("#{error_scope}.errors.invalid_receipt_quantity", variant: line.variant_name))
        end
        return nil if accepted.zero? && rejected.zero?

        {
          line: line,
          quantity_accepted: accepted,
          quantity_rejected: rejected,
          rejection_reason: item[:rejection_reason].presence,
          notes: item[:notes].presence
        }
      end

      # Two entries for one line are genuinely ambiguous — two cartons, or a
      # correction of the first? — so they are refused rather than merged.
      def reject_repeated_lines
        lines = Array(items).map { |item| item[:item] }.compact
        repeated = lines.group_by(&:id).values.find { |group| group.length > 1 }
        return if repeated.nil?

        failure(receivable, Spree.t("#{error_scope}.errors.repeated_item", variant: repeated.first.variant_name))
      end

      def build_receipt
        @stock_receipt = receivable.stock_receipts.build(
          store: receivable.store,
          received_at: received_at.presence || Time.current,
          reference: reference,
          notes: notes,
          received_by: received_by
        )
        @normalized_items.each { |entry| @stock_receipt.items.build(entry) }

        failure(@stock_receipt) unless @stock_receipt.save
      end

      def update_lines
        @normalized_items.each do |entry|
          line = entry[:line]
          line.update!(
            quantity_received: line.quantity_received.to_i + entry[:quantity_accepted],
            quantity_rejected: line.quantity_rejected.to_i + entry[:quantity_rejected]
          )
        end
      end

      # Only accepted units land. The receipt is the cause, and brings the
      # document's own foreign key with it.
      def restock_accepted
        destination = receivable.destination_location

        @normalized_items.each do |entry|
          next unless entry[:quantity_accepted].positive?

          destination.restock(entry[:line].variant, entry[:quantity_accepted], stock_receipt,
                              unit_cost: unit_cost_for(entry[:line]))
        end
      end

      # `received_at` is stamped only when the document actually closes, in
      # full or over — a partial delivery leaves it open.
      def settle_status
        # The caller's lines are freshly-loaded instances, not the ones the
        # association is holding, so the totals have to be re-read before they
        # can decide the status.
        receivable.items.reset
        status = receivable.status_after_receive
        attributes = { status: status }
        attributes[:received_at] = Time.current if Spree::Receivable::CLOSED_STATUSES.include?(status)

        failure(receivable) unless receivable.update(attributes)
      end
    end
  end
end
