module Spree
  class Order < Spree::Base
    module Payments
      extend ActiveSupport::Concern
      included do
        # processes any pending payments and must return a boolean as it's
        # return value is used by the checkout state_machine to determine
        # success or failure of the 'complete' event for the order
        #
        # Returns:
        #
        # - true if all pending_payments processed successfully
        #
        # - true if a payment failed, ie. raised a GatewayError
        #   which gets rescued and converted to TRUE when
        #   :allow_checkout_gateway_error is set to true
        #
        # - false if a payment failed, ie. raised a GatewayError
        #   which gets rescued and converted to FALSE when
        #   :allow_checkout_on_gateway_error is set to false
        #
        def process_payments!
          process_payments_with(:process!)
        end

        def authorize_payments!
          process_payments_with(:authorize!)
        end

        def capture_payments!
          process_payments_with(:purchase!)
        end

        def pending_payments
          payments.select(&:pending?)
        end

        def unprocessed_payments
          payments.select(&:checkout?)
        end

        private

        def process_payments_with(method)
          # Don't run if there is nothing to pay.
          return if payment_total >= total
          # Prevent orders from transitioning to complete without a successfully processed payment.
          raise Core::GatewayError, Spree.t(:no_payment_found) if unprocessed_payments.empty?

          unprocessed_payments.each do |payment|
            break if payment_total >= total

            payment.public_send(method)

            # Payment updates the order total if capture_on_dispatch is *not* set; don't do this twice
            # See: https://github.com/spree/spree/issues/8148
            if payment.completed? && payment.capture_on_dispatch
              self.payment_total += payment.amount
            end
          end
        rescue Core::GatewayError => e
          result = !!Spree::Config[:allow_checkout_on_gateway_error]
          errors.add(:base, e.message) && (return result)
        end
      end
    end
  end
end
