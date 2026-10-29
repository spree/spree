module SpreePaypalCheckout
  # PayPal Checkout gateway built on the payment session API. A session is a
  # PayPal order: the buyer approves it in PayPal's window, then the server
  # captures or authorizes it, so the server is the only thing that moves money.
  class Gateway < ::Spree::Gateway
    self.accepts_money_amounts = true

    preference :client_id, :password
    preference :client_secret, :password
    # The credentials do not say which PayPal environment they belong to.
    preference :test_mode, :boolean, default: true
    # Written by webhook registration, never by an operator.
    preference :webhook_id, :string, internal: true

    validates :preferred_client_id, :preferred_client_secret, presence: true

    def self.logo_url
      'https://spreecommerce.org/docs/images/integrations/logos/paypal.png'
    end

    def self.docs_url
      'https://spreecommerce.org/docs/integrations/payments/paypal'
    end

    def provider_class
      self.class
    end

    def default_name
      'PayPal'
    end

    def method_type
      'spree_paypal_checkout'
    end

    def payment_icon_name
      'paypal'
    end

    def session_required?
      true
    end

    def payment_session_class
      Spree::PaymentSessions::PaypalCheckout
    end

    # No saved PayPal accounts in this release, so core never calls
    # create_profile and passes no source to credit and void.
    def payment_profiles_supported?
      false
    end

    def available_for_order?(order)
      super && SpreePaypalCheckout::Amounts.supported_currency?(order.currency)
    end

    # CAPTURE takes the money when the session completes; AUTHORIZE holds it
    # for Spree to capture on dispatch or by hand.
    #
    # @return [String]
    def paypal_intent
      if capture_at_checkout?
        PaypalServerSdk::CheckoutPaymentIntent::CAPTURE
      else
        PaypalServerSdk::CheckoutPaymentIntent::AUTHORIZE
      end
    end
  end
end
