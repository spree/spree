require_dependency 'spree/payment/gateway_options'

module Spree
  class Payment < Spree::Base
    module Processing
      extend ActiveSupport::Concern
      included do
        class_attribute :gateway_options_class
        self.gateway_options_class = Spree::Payment::GatewayOptions
      end

      def process!
        if payment_method&.auto_capture?
          purchase!
        else
          authorize!
        end
      end

      def authorize!
        handle_payment_preconditions { process_authorization }
      end

      # Captures the entire amount of a payment.
      def purchase!
        handle_payment_preconditions { process_purchase }
      end

      # Takes the amount in cents to capture.
      # Can be used to capture partial amounts of a payment, and will create
      # a new pending payment record for the remaining amount to capture later.
      def capture!(amount = nil)
        return true if completed?

        amount ||= money.amount_in_cents
        started_processing!
        protect_from_connection_error do
          # Standard ActiveMerchant capture usage
          response = payment_method.capture(
            amount,
            response_code,
            gateway_options
          )
          money = ::Money.new(amount, currency)
          capture_events.create!(amount: money.to_f)
          split_uncaptured_amount
          handle_response(response, :complete, :failure)
        end
      end

      def void_transaction!
        return true if void?

        protect_from_connection_error do
          if payment_method.payment_profiles_supported?
            # Gateways supporting payment profiles will need access to credit card object because this stores the payment profile information
            # so supply the authorization itself as well as the credit card, rather than just the authorization code
            response = payment_method.void(response_code, source, gateway_options)
          else
            # Standard ActiveMerchant void usage
            response = payment_method.void(response_code, gateway_options)
          end
          record_response(response)

          if response.success?
            self.response_code = response.authorization
            void
          else
            gateway_error(response)
          end
        end
      end

      def cancel!
        response = payment_method.cancel(response_code)
        handle_response(response, :void, :failure)
      end

      def gateway_options
        order.reload
        gateway_options_class.new(self).to_hash
      end

      private

      def process_authorization
        started_processing!
        gateway_action(source, :authorize, :pend)
      end

      def process_purchase
        started_processing!
        result = gateway_action(source, :purchase, :complete)
        # This won't be called if gateway_action raises a GatewayError
        capture_events.create!(amount: amount)
      end

      def handle_payment_preconditions
        unless block_given?
          raise ArgumentError, 'handle_payment_preconditions must be called with a block'
        end

        if payment_method&.source_required?
          if source
            unless processing?
              if payment_method.supports?(source) || token_based?
                yield
              else
                invalidate!
                raise Core::GatewayError, Spree.t(:payment_method_not_supported)
              end
            end
          else
            raise Core::GatewayError, Spree.t(:payment_processing_failed)
          end
        end
      end

      def gateway_action(source, action, success_state)
        protect_from_connection_error do
          response = payment_method.send(action, money.amount_in_cents,
                                         source,
                                         gateway_options)
          handle_response(response, success_state, :failure)
        end
      end

      def handle_response(response, success_state, failure_state)
        record_response(response)

        if response.success?
          unless response.authorization.nil?
            self.response_code = response.authorization
            self.avs_response = response.avs_result['code']

            if response.cvv_result
              self.cvv_response_code = response.cvv_result['code']
              self.cvv_response_message = response.cvv_result['message']
            end
          end
          send("#{success_state}!")
        else
          send(failure_state)
          gateway_error(response)
        end
      end

      def record_response(response)
        log_entries.create!(details: response.to_yaml)
      end

      def protect_from_connection_error
        yield
      rescue ActiveMerchant::ConnectionError => e
        gateway_error(e)
      end

      def gateway_error(error)
        text = if error.is_a? ActiveMerchant::Billing::Response
                 error.params['message'] || error.params['response_reason_text'] || error.message
               elsif error.is_a? ActiveMerchant::ConnectionError
                 Spree.t(:unable_to_connect_to_gateway)
               else
                 error.to_s
               end
        logger.error(Spree.t(:gateway_error))
        logger.error("  #{error.to_yaml}")
        raise Core::GatewayError, text
      end

      def token_based?
        source.gateway_customer_profile_id.present? || source.gateway_payment_profile_id.present?
      end
    end
  end
end
