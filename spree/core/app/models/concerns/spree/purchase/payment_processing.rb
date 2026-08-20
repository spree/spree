module Spree
  module Purchase
    # Payment processing shared by Spree::Cart and Spree::Order.
    module PaymentProcessing
      # Processes any pending payments, recording a gateway failure on
      # +errors+. The completion workflows check whether payments actually
      # cover the total rather than trusting the return value.
      #
      # Deliberately not locked: holding the order's row lock across gateway
      # round trips is what the workflow external_step boundary exists to
      # prevent. Concurrent processing of the same payment is guarded twice —
      # the workflow's atomic claim refuses a payment another writer settled,
      # and the gateway idempotency key (spree-<payment.number>) makes a
      # duplicate charge a no-op at the provider.
      def process_payments!
        # with_lock used to reload the record as a side effect; callers create
        # payments right before processing, so the association must refresh.
        payments.reset
        process_payments_with(nil)
      end

      def authorize_payments!
        process_payments_with(:authorize)
      end

      def capture_payments!
        process_payments_with(:purchase)
      end

      def pending_payments
        payments.pending
      end

      # Active front-end payment methods available for this record.
      #
      # @return [Array<Spree::PaymentMethod>]
      def payment_methods
        store.payment_methods.active.storefront_visible.select { |payment_method| payment_method.available_for_order?(self) }
      end

      # Free checkouts have no money to collect.
      #
      # @return [Boolean]
      def payment_required?
        total.to_f > 0.0
      end

      # Whether a confirm/review pass is expected before completion —
      # computed from data only.
      #
      # @return [Boolean]
      def confirmation_required?
        Spree::Config[:always_include_confirm_step] ||
          payments.valid.map(&:payment_method).compact.any?(&:confirmation_required?)
      end

      def unprocessed_payments
        payments.select(&:checkout?)
      end

      private

      def process_payments_with(action)
        # Don't run if there is nothing to pay. Read from the database, not
        # the in-memory attribute: settlements land through the order status
        # subscriber, which holds its own instance of this record, so the
        # attribute here goes stale as soon as anything settles. Only that
        # column is read — reloading the whole record would discard in-memory
        # state the caller set.
        return if settled_payment_total >= total
        # Don't run if there are authorized payments
        return if pending_payments.any? && unprocessed_payments.empty?
        # Never complete without a successfully processed payment.
        raise Spree::Core::GatewayError, Spree.t(:no_payment_found) if unprocessed_payments.empty?

        unprocessed_payments.each do |payment|
          break if settled_payment_total >= total

          result = Spree.payment_process_workflow.call(payment: payment, action: action)
          raise Spree::Core::GatewayError, result.error.value.to_s if result.failure?
        end
      rescue Spree::Core::GatewayError => e
        errors.add(:base, e.message)
        false
      end

      # @return [BigDecimal] payment_total as it stands in the database
      def settled_payment_total
        persisted? ? self.class.where(id: id).pick(:payment_total).to_d : payment_total.to_d
      end
    end
  end
end
