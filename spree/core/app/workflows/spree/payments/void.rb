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
        success(payment)
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
          mark_void
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
          mark_void(authorization: response.authorization)
        else
          payment.gateway_error(response)
        end
      rescue Spree::Core::GatewayError => error
        failure(payment, error.message)
      end

      # A compare-and-swap, like the session transitions: of two racing
      # voids only the writer whose update moves the row publishes — the
      # loser lands as idempotent success. There is no pre-gateway claim,
      # because the gateway is the authority on whether the authorization
      # can still be released; only the terminal write must never double.
      # The authorization is written only when the gateway returned one —
      # a successful void without it must not null the stored reference.
      def mark_void(authorization: nil)
        if payment.new_record?
          payment.status = 'void'
          payment.response_code = authorization if authorization.present?
          payment.save!
          payment.publish_event('payment.voided')
          return
        end

        updates = { status: 'void', updated_at: Time.current }
        updates[:response_code] = authorization if authorization.present?

        claimed = Spree::Payment.where(id: payment.id).where.not(status: 'void')
                                .update_all(updates) == 1
        return unless claimed

        payment.assign_attributes(updates.except(:updated_at))
        payment.clear_attribute_changes(updates.except(:updated_at).keys)
        payment.publish_event('payment.voided')
      end
    end
  end
end
