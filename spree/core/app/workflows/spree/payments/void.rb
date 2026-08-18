module Spree
  module Payments
    # Voids an authorized payment at the gateway.
    #
    # Owns the flow end to end; Spree::Payment keeps only gateway
    # mechanics. The payment.voided event publishes from the void! write
    # itself.
    class Void < Spree::Workflow
      include Spree::InstrumentsGatewayCalls

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

      def void_at_gateway
        # Nothing ever reached the gateway, so there is nothing to release.
        if payment.response_code.blank?
          payment.void!
          return
        end

        response = payment.protect_from_connection_error do
          instrument_gateway_call(:void, payment.payment_method) do
            if payment.payment_method.payment_profiles_supported?
              # Profile gateways need the source: it carries the stored
              # payment profile, not just the authorization code.
              payment.payment_method.void(payment.response_code, payment.source, payment.gateway_options)
            else
              payment.payment_method.void(payment.response_code, payment.gateway_options)
            end
          end
        end

        if response.success?
          payment.response_code = response.authorization
          payment.void!
        else
          payment.gateway_error(response)
        end
      rescue Spree::Core::GatewayError => error
        failure(payment, error.message)
      end
    end
  end
end
