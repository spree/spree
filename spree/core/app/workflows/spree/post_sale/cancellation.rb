module Spree
  module PostSale
    # Cancellation shared by returns, exchanges and claims. The including
    # workflow names the record it cancels (`post_sale_record`) and the
    # statuses it may be cancelled from (`cancellable_statuses`). A caller
    # may narrow those with `only_from:` — the customer withdraws only what the
    # merchant has not acted on. A block runs after the cancellation commits,
    # for work outside the database.
    module Cancellation
      include Spree::Refunds::TaxCredit

      private

      def cancel
        step :ensure_cancellable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_canceled
          step :clear_tax
        end

        yield if block_given?

        run_hooks :after_cancel
        post_sale_record.publish_event("#{post_sale_record.event_prefix}.canceled")
        success(post_sale_record.reload)
      end

      def ensure_cancellable
        return if post_sale_record.status.in?(allowed_statuses)

        failure(post_sale_record, :not_cancellable)
      end

      def allowed_statuses
        only_from.present? ? cancellable_statuses & Array(only_from) : cancellable_statuses
      end

      # Checked again under the row lock: a merchant approving the record
      # between the check above and this write must win.
      def mark_canceled
        post_sale_record.lock!
        ensure_cancellable
        memo = [post_sale_record.memo, reason].compact_blank.join("\n")
        post_sale_record.update!(status: 'canceled', canceled_at: Time.current, memo: memo.presence)
      end

      def clear_tax
        clear_tax_credit(post_sale_record)
      end
    end
  end
end
