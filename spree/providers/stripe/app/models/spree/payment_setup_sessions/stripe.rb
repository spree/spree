module Spree
  class PaymentSetupSessions::Stripe < PaymentSetupSession
    delegate :api_options, to: :payment_method

    def stripe_id
      external_id
    end

    def client_secret
      external_client_secret
    end

    def stripe_setup_intent
      @stripe_setup_intent ||= payment_method.retrieve_setup_intent(external_id)
    end

    def successful?
      stripe_setup_intent.status == 'succeeded'
    end
  end
end
