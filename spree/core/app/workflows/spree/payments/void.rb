module Spree
  module Payments
    # Voids an authorized payment at the gateway.
    #
    # In the workflow tier because the void is network I/O — the external_step
    # keeps it out of any transaction the workflow opened. Money movement
    # stays in the model (Payment#void_transaction! and the state machine are
    # unchanged); this owns the boundary, the guards and the extension points
    # around it.
    class Void < Spree::Workflow
      hooks :validate, :before_void, :after_void

      # @param payment [Spree::Payment] an already-void payment is a no-op
      def perform(payment:)
        super

        step :ensure_voidable
        # Veto point — before the authorization is released.
        run_hooks :validate
        run_hooks :before_void

        external_step :void_at_gateway

        run_hooks :after_void
        success(payment.reload)
      end

      private

      # An already-void payment returns success rather than failing: void is
      # naturally idempotent and double-submitted admin actions must not
      # surface as errors.
      def ensure_voidable
        halt!(payment) if payment.void?
        failure(payment, :payment_not_voidable) unless payment.can_void?
      end

      # The payment.voided event publishes from the state transition itself.
      def void_at_gateway
        payment.void_transaction!
      rescue Spree::Core::GatewayError => error
        failure(payment, error.message)
      end
    end
  end
end
