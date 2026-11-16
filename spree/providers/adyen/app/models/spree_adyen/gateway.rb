module SpreeAdyen
  # Adyen gateway built on the payment session API: Adyen's Sessions flow with
  # Drop-in. A session payment's response code is always its Adyen session id,
  # the key core links a session to its payment by; the PSP reference Adyen
  # needs for a capture, cancel or refund lives in the payment's metadata.
  class Gateway < ::Spree::Gateway
    self.accepts_money_amounts = true

    # Typed by the operator.
    preference :api_key, :password
    preference :merchant_account, :string
    preference :test_mode, :boolean, default: true
    # Adyen's live Checkout endpoints need it; the Management API does not.
    preference :live_url_prefix, :string

    # Written by configuration after save, never by an operator.
    preference :client_key, :password, internal: true
    preference :hmac_key, :password, internal: true
    preference :previous_hmac_key, :password, internal: true
    preference :webhook_id, :string, internal: true

    validates :preferred_api_key, :preferred_merchant_account, presence: true
    validates :preferred_live_url_prefix, presence: true, unless: :preferred_test_mode

    def self.logo_url
      'https://spreecommerce.org/docs/images/integrations/logos/adyen.png'
    end

    def self.docs_url
      'https://spreecommerce.org/docs/integrations/payments/adyen'
    end

    def provider_class
      self.class
    end

    def default_name
      'Adyen'
    end

    def method_type
      'spree_adyen'
    end

    def payment_icon_name
      'adyen'
    end

    def session_required?
      true
    end

    def payment_session_class
      Spree::PaymentSessions::Adyen
    end

    def payment_setup_session_class
      Spree::PaymentSetupSessions::Adyen
    end

    # Cards are saved under the customer's shopper reference, and core passes
    # the source to void and credit.
    def payment_profiles_supported?
      true
    end
  end
end
