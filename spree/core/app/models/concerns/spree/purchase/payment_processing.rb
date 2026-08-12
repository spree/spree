module Spree
  module Purchase
    # Payment processing shared by Spree::Cart and Spree::Order.
    module PaymentProcessing
      # Processes any pending payments, recording a gateway failure on
      # +errors+. The completion workflows check whether payments actually
      # cover the total rather than trusting the return value.
      def process_payments!
        with_lock { process_payments_with(:process!) }
      end

      def authorize_payments!
        process_payments_with(:authorize!)
      end

      def capture_payments!
        process_payments_with(:purchase!)
      end

      def pending_payments
        payments.pending
      end

      # Active front-end payment methods available for this record.
      #
      # @return [Array<Spree::PaymentMethod>]
      def payment_methods
        store.payment_methods.active.available_on_front_end.select { |payment_method| payment_method.available_for_order?(self) }
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

      def process_payments_with(method)
        # Don't run if there is nothing to pay.
        return if payment_total >= total
        # Don't run if there are authorized payments
        return if pending_payments.any? && unprocessed_payments.empty?
        # Never complete without a successfully processed payment.
        raise Spree::Core::GatewayError, Spree.t(:no_payment_found) if unprocessed_payments.empty?

        unprocessed_payments.each do |payment|
          break if payment_total >= total

          payment.public_send(method)
        end
      rescue Spree::Core::GatewayError => e
        errors.add(:base, e.message)
        false
      end
    end
  end
end
