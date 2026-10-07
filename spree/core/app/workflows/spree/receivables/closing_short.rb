module Spree
  module Receivables
    # Ends a purchase order or transfer whose missing units are not going to
    # turn up. Nothing is written to any shelf: closing short keeps what was
    # received, records why the rest never arrived, and leaves the outstanding
    # count on each line as the record of the gap. The including workflow
    # names the document (`receivable`).
    module ClosingShort
      include IncomingCounter

      private

      def close
        receivable.with_lock do
          step :ensure_closable
          run_hooks :validate
          step :uncount_awaited_units
          step :close_short
        end

        run_hooks :after_close
        receivable.publish_event("#{receivable.event_prefix}.received")
        success(receivable.reload)
      end

      def ensure_closable
        return if receivable.partially_received?

        failure(receivable, I18n.t("spree.#{receivable.event_prefix}.errors.not_partially_received"))
      end

      # The balance is not coming, so it leaves the destination's incoming
      # figure; each line's outstanding count keeps the record.
      def uncount_awaited_units
        uncount_incoming(receivable)
      end

      def close_short
        now = Time.current
        attributes = { status: 'received', received_at: now, closed_short_at: now, close_reason: reason.presence }

        failure(receivable) unless receivable.update(attributes)
      end
    end
  end
end
