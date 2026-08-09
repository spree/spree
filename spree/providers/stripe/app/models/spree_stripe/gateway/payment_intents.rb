module SpreeStripe
  class Gateway < ::Spree::Gateway
    # Stripe payment intents are API objects rather than Spree records — the
    # payment session owns their lifecycle and stores the intent id as its
    # external id.
    module PaymentIntents
      extend ActiveSupport::Concern

      # Banks confirm these asynchronously, so `processing` is as good as accepted.
      DELAYED_NOTIFICATION_PAYMENT_METHOD_TYPES = %w[sepa_debit us_bank_account].freeze
      # Funds arrive out of band, leaving the intent in `requires_action`.
      BANK_PAYMENT_METHOD_TYPES = %w[customer_balance us_bank_account].freeze
      MANUAL_CAPTURE_METHOD = 'manual'.freeze

      def payment_intent_accepted?(payment_intent)
        payment_intent.status.in?(payment_intent_accepted_statuses(payment_intent))
      end

      def payment_intent_successful?(payment_intent)
        payment_intent.status == 'succeeded'
      end

      def payment_intent_requires_capture?(payment_intent)
        payment_intent.status == 'requires_capture'
      end

      def payment_intent_delayed_notification?(payment_intent)
        payment_intent_type_in?(payment_intent, DELAYED_NOTIFICATION_PAYMENT_METHOD_TYPES)
      end

      # Bank transfers settle without a charge object, so the source has to be
      # built from the intent instead.
      def payment_intent_charge_not_required?(payment_intent)
        payment_intent_type_in?(payment_intent, BANK_PAYMENT_METHOD_TYPES)
      end

      def payment_intent_manual_capture?(payment_intent)
        payment_intent.respond_to?(:capture_method) && payment_intent.capture_method == MANUAL_CAPTURE_METHOD
      end

      # @param amount_in_cents [Integer]
      # @param order [Spree::Order, Spree::Cart]
      # @param payment_method_id [String, nil] Stripe payment method id, eg. pm_123
      # @param customer_profile_id [String, nil] Stripe customer id, eg. cus_123
      # @return [Spree::PaymentResponse]
      def create_payment_intent(amount_in_cents, order, payment_method_id: nil, customer_profile_id: nil)
        payload = SpreeStripe::PaymentIntentPresenter.new(
          amount: amount_in_cents,
          order: order,
          customer: customer_profile_id,
          payment_method_id: payment_method_id,
          capture_method: stripe_capture_method
        ).call

        protect_from_error do
          response = send_request { |opts| Stripe::PaymentIntent.create(payload, opts) }

          success(response.id, response)
        end
      end

      # @param payment_intent_id [String] eg. pi_123
      # @return [Spree::PaymentResponse]
      def update_payment_intent(payment_intent_id, amount_in_cents, order, payment_method_id = nil)
        protect_from_error do
          payload = SpreeStripe::PaymentIntentPresenter.new(
            amount: amount_in_cents,
            order: order,
            customer: fetch_or_create_customer(order: order)&.profile_id,
            payment_method_id: payment_method_id
          ).call.slice(:amount, :currency, :payment_method, :shipping, :customer)

          response = send_request { |opts| Stripe::PaymentIntent.update(payment_intent_id, payload, opts) }

          success(response.id, response)
        end
      end

      def retrieve_payment_intent(payment_intent_id)
        send_request { |opts| Stripe::PaymentIntent.retrieve({ id: payment_intent_id, expand: ['payment_method'] }, opts) }
      end

      def confirm_payment_intent(payment_intent_id)
        send_request { |opts| Stripe::PaymentIntent.confirm(payment_intent_id, {}, opts) }
      end

      def capture_payment_intent(payment_intent_id, amount_in_cents)
        send_request { |opts| Stripe::PaymentIntent.capture(payment_intent_id, { amount_to_capture: amount_in_cents }, opts) }
      end

      def cancel_payment_intent(payment_intent_id)
        send_request { |opts| Stripe::PaymentIntent.cancel(payment_intent_id, {}, opts) }
      end

      private

      def payment_intent_type_in?(payment_intent, types)
        payment_method = payment_intent.payment_method
        return false unless payment_method.respond_to?(:type)

        payment_method.type.in?(types)
      end

      def stripe_capture_method
        auto_capture? ? nil : MANUAL_CAPTURE_METHOD
      end

      def payment_intent_accepted_statuses(payment_intent)
        statuses = %w[succeeded]
        statuses << 'requires_capture' if payment_intent_manual_capture?(payment_intent)
        statuses << 'processing' if payment_intent_delayed_notification?(payment_intent)
        statuses << 'requires_action' if payment_intent_charge_not_required?(payment_intent)
        statuses
      end
    end
  end
end
