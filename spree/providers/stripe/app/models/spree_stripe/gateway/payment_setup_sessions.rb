module SpreeStripe
  class Gateway < ::Spree::Gateway
    # Saving a payment method for later use, without taking a payment.
    module PaymentSetupSessions
      extend ActiveSupport::Concern

      def setup_session_supported?
        true
      end

      def payment_setup_session_class
        Spree::PaymentSetupSessions::Stripe
      end

      # @param customer [Spree::Customer]
      # @return [Spree::PaymentSetupSessions::Stripe]
      def create_payment_setup_session(customer:, external_data: {})
        gateway_customer = fetch_or_create_customer(customer: customer)

        setup_intent_response = create_setup_intent(gateway_customer.profile_id)
        ephemeral_key_response = create_ephemeral_key(gateway_customer.profile_id)

        payment_setup_session_class.create!(
          customer: customer,
          payment_method: self,
          status: 'pending',
          external_id: setup_intent_response.params['id'],
          external_client_secret: setup_intent_response.authorization,
          external_data: external_data.to_h.stringify_keys.merge(
            'customer_id' => gateway_customer.profile_id,
            'ephemeral_key_secret' => ephemeral_key_response&.params&.dig('secret')
          ).compact
        )
      end

      def complete_payment_setup_session(setup_session:, params: {})
        stripe_setup_intent = retrieve_setup_intent(setup_session.external_id)

        if stripe_setup_intent.status == 'succeeded'
          setup_session.process if setup_session.can_process?

          stripe_payment_method = stripe_setup_intent.payment_method

          setup_session.payment_source = SpreeStripe::CreateSource.new(
            stripe_payment_method_details: stripe_payment_method,
            stripe_payment_method_id: stripe_payment_method.id,
            stripe_billing_details: stripe_payment_method.billing_details,
            gateway: self,
            customer: setup_session.customer
          ).call

          setup_session.complete unless setup_session.completed?
        else
          setup_session.fail if setup_session.can_fail?
        end

        setup_session
      end

      def retrieve_setup_intent(setup_intent_id)
        send_request { |opts| Stripe::SetupIntent.retrieve({ id: setup_intent_id, expand: ['payment_method'] }, opts) }
      end
    end
  end
end
