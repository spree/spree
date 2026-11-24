module Spree
  module Payments
    # Applies a provider's answer to a capture, void or refund it accepted
    # earlier: the outcome a gateway that answered +requested?+ reports by
    # webhook.
    #
    # A repeat delivery changes nothing: an outcome for a record already past
    # +requested+ is ignored, except a failure arriving after a success, which
    # providers may send days later and which takes the money back.
    class HandleModificationWebhook < Spree::Workflow
      # The record each outcome settles, as PaymentMethod#modification_record finds it.
      RECORD_CLASSES = {
        'capture_event' => 'Spree::PaymentCaptureEvent',
        'payment' => 'Spree::Payment',
        'refund' => 'Spree::Refund'
      }.freeze
      OUTCOME_RECORDS = {
        capture_succeeded: 'capture_event', capture_failed: 'capture_event',
        void_succeeded: 'payment', void_failed: 'payment',
        refund_succeeded: 'refund', refund_failed: 'refund'
      }.freeze

      # @param payment_method [Spree::PaymentMethod] the method that received the webhook
      # @param action [Symbol] one of the six outcomes
      # @param record [Spree::PaymentCaptureEvent, Spree::Payment, Spree::Refund]
      #   the capture event, payment or refund the outcome names
      # @param metadata [Hash] the provider's reason for a failure under 'reason'
      def perform(payment_method:, action:, record:, metadata: {})
        super
        @payment = record.is_a?(Spree::Payment) ? record : record.payment
        @events = []

        step :ensure_known_outcome
        step :ensure_payment_method_owns_record

        step :apply_outcome
        external_step :authorize_remainder
        step :rederive_order_figures

        @events.each { |(publisher, name, metadata)| publisher.publish_event(name, nil, metadata || {}) }
        success(record)
      end

      private

      attr_reader :payment, :remainder

      def ensure_known_outcome
        expected = RECORD_CLASSES[OUTCOME_RECORDS[action]]&.constantize

        mismatch!("#{action} does not name a #{record.class.name}") unless expected && record.is_a?(expected)
      end

      def ensure_payment_method_owns_record
        mismatch!('The outcome names a payment of another payment method') unless payment.payment_method_id == payment_method.id
      end

      # A parser naming the wrong record fails the same way on every retry, so
      # it is reported and the delivery is not acted on.
      def mismatch!(message)
        Rails.error.report(ArgumentError.new(message),
                           handled: true, context: { record: record.class.name, record_id: record.id },
                           source: 'spree.payments.modification_webhook')
        halt!(record)
      end

      # Locked because a redelivery of the same outcome races this one, and
      # the capture request that wrote the record may still be finishing.
      #
      # The payment's orders are locked before the payment itself, in the
      # order returns, claims and exchanges take them (the order, then
      # Spree::Refunds::Create the payment): settling a share writes its
      # order's payment total, so a payment-first lock here would deadlock
      # against a refund holding the order.
      def apply_outcome
        ApplicationRecord.transaction do
          Spree::Order.where(id: payment_order_ids).order(:id).lock.pluck(:id)

          payment.with_lock do
            record.reload
            # A session payment carries no Spree-side source unless its gateway
            # built one, so the requirement is skipped, as settlement does.
            payment.skip_source_requirement = true if payment.source.blank?

            case action
            when :capture_succeeded then capture_succeeded
            when :capture_failed then capture_failed
            when :void_succeeded then void_succeeded
            when :void_failed then void_failed
            when :refund_succeeded then refund_succeeded
            when :refund_failed then refund_failed
            end
          end
        end
      end

      def capture_succeeded
        return unless record.requested?

        record.update!(status: 'completed')
        # Split before completing, so payment.completed publishes with the
        # captured amount, as the capture workflow does for an answer given at once.
        @remainder = payment.split_uncaptured_amount
        payment.complete!
        settle_claimed_share(record.amount, captured: true)
        @events << [payment, 'payment.captured']
      end

      def capture_failed
        return if record.failed?

        @late_failure = record.completed?
        record.update!(status: 'failed')
        payment.update!(status: 'failed')
        record_reason_on_payment

        if @late_failure
          take_back_captured_share(record.amount)
        else
          settle_claimed_share(record.amount, captured: false)
        end
        @events << [payment, 'payment.capture_failed']
      end

      def void_succeeded
        return unless payment.requested_action == 'void'

        payment.void!
      end

      # The authorization still holds, so the payment goes back to what it was:
      # captured if money was taken, otherwise waiting for a capture.
      def void_failed
        return unless payment.requested_action == 'void'

        payment.update!(status: payment.captured_amount.positive? ? 'completed' : 'pending')
        record_reason_on_payment
        @events << [payment, 'payment.void_failed']
      end

      def refund_succeeded
        return unless record.requested?

        record.update!(status: 'completed')
        @events << [payment, 'payment.refunded', { refund_id: record.prefixed_id }]
      end

      def refund_failed
        return if record.failed?

        record.update!(status: 'failed', failure_reason: reason)
        @events << [record, 'refund.failed']
      end

      # A split-checkout parcel reserved its share before asking the provider;
      # the outcome turns that claim into captured money, or releases it.
      def settle_claimed_share(amount, captured:)
        remaining = amount
        payment.payment_splits.each do |split|
          next unless split.capture_in_flight? && remaining.positive?

          # Under the share's own lock, as dispatch writes it, so a parcel
          # claiming the same share meanwhile is not overwritten.
          settled = split.with_lock do
            [split.claimed_amount, remaining].min.tap { |amount| split.settle_claim!(amount, captured: captured) }
          end
          remaining -= settled
        end
      end

      def take_back_captured_share(amount)
        remaining = amount
        payment.payment_splits.each do |split|
          taken_back = split.with_lock do
            [split.captured_amount, remaining].min.tap do |amount|
              split.update!(captured_amount: split.captured_amount - amount) if amount.positive?
            end
          end
          remaining -= taken_back if taken_back.positive?
        end
      end

      def record_reason_on_payment
        payment.add_gateway_processing_error(reason) if reason.present?
      end

      def reason
        metadata['reason'] || metadata[:reason]
      end

      # The remainder's authorization is its own network call, so it stays
      # outside the lock. The capture is already recorded, so a remainder the
      # gateway cannot authorize (one with no session of its own) is reported
      # and left pending rather than failing the outcome, which a retry could
      # not change.
      def authorize_remainder
        return if remainder.blank?
        # Holding more than the order still owes would only keep the
        # customer's money tied up.
        return unless remainder.trim_remainder_to_amount_owed!

        result = Spree.payment_process_workflow.call(payment: remainder, action: :authorize)
        return if result.success?

        Rails.error.report(Spree::Core::GatewayError.new(result.error.value.to_s),
                           handled: true, context: { payment_id: remainder.id }, source: 'spree.payments.modification_webhook')
      end

      # A refund settled or a capture failed, so the orders' totals and
      # statuses are derived again. Decided by the outcome, not by whether this
      # delivery moved the record, so a redelivery or a retried job repairs a
      # refresh that failed after the outcome committed; deriving is idempotent.
      def rederive_order_figures
        return unless record.is_a?(Spree::Refund) || action.to_sym == :capture_failed

        orders = record.is_a?(Spree::Refund) ? [record.order] : payment_orders
        orders.compact.each do |order|
          order.recalculate_totals!
          order.update_statuses!
        end
      end

      def payment_orders
        payment.grouped? ? Spree::Order.where(id: payment_order_ids).to_a : [payment.order]
      end

      def payment_order_ids
        payment.grouped? ? payment.payment_splits.pluck(:order_id) : [payment.order_id].compact
      end
    end
  end
end
