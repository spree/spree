module SpreeEasyPost
  # Per-store EasyPost credentials. The API key decides the mode — EasyPost
  # issues separate test and production keys, so there is no mode toggle.
  class Integration < Spree::Integration
    # EasyPost rejects any other value outright, and a rejected shipment
    # create is a checkout with no delivery options at all.
    INCOTERMS = %w[CFR CIF CIP CPT DAT DAP DDP EXW FAS FCA FOB].freeze
    # EasyPost's contents enum minus `other`, which additionally demands a
    # free-text explanation nothing here supplies — offering it would only
    # produce a rejected declaration.
    CUSTOMS_CONTENTS_TYPES = %w[documents gift merchandise returned_goods sample dangerous_goods humanitarian_donation].freeze

    # Declared credentials first: they are the two an operator must supply,
    # and the form renders in this order.
    preference :api_key, :password
    # The shared secret configured on the EasyPost webhook; signs every
    # delivery. Without it webhooks are refused — an unauthenticated report
    # could otherwise mark parcels delivered, which starts return windows.
    preference :webhook_secret, :password

    # Customs declaration defaults, used only on international labels. The
    # signer takes legal responsibility for the declared contents, so it names
    # a person at the merchant rather than the store.
    preference :customs_signer, :string
    preference :customs_contents_type, :string, default: 'merchandise', in: CUSTOMS_CONTENTS_TYPES
    # Who pays duties and taxes on arrival. Defaults to DAP — the recipient is
    # billed by the carrier. DDP bills the merchant instead, so only choose it
    # once duties are actually collected from the customer at checkout;
    # otherwise the merchant absorbs them silently.
    preference :incoterm, :string, default: 'DAP', in: INCOTERMS

    validates :preferred_incoterm, inclusion: { in: INCOTERMS }, allow_blank: true
    validates :preferred_customs_contents_type, inclusion: { in: CUSTOMS_CONTENTS_TYPES }, allow_blank: true

    # EasyPost's own documentation example address — used only to prove the
    # key authenticates.
    VERIFICATION_ADDRESS = {
      street1: '417 Montgomery Street',
      city: 'San Francisco',
      state: 'CA',
      zip: '94104',
      country: 'US'
    }.freeze

    def self.integration_group
      'shipping'
    end

    # Verifies the EasyPost HMAC signature and translates `tracker.updated`
    # payloads into UpdateTracking arguments. Non-tracker events (batches,
    # refund confirmations) return nil and are acknowledged without action.
    def parse_webhook_event(raw_post, headers)
      raise Spree::Integration::WebhookSignatureError, 'webhook secret not configured' if preferred_webhook_secret.blank?

      payload = EasyPost::Util.validate_webhook(raw_post, headers, preferred_webhook_secret)

      SpreeEasyPost::TrackerEvent.from_webhook(payload)&.to_update_tracking_arguments
    rescue EasyPost::Errors::SignatureVerificationError => e
      raise Spree::Integration::WebhookSignatureError, e.message
    end

    def self.integration_name
      SpreeEasyPost::PROVIDER_NAME
    end

    def self.logo_url
      'https://www.easypost.com/wp-content/uploads/2026/03/EasyPost-Logo.svg'
    end

    # Fallback for hosts without the gem's translations; the localized
    # description in config/locales wins.
    def self.description
      'Live multi-carrier delivery rates at checkout through your EasyPost account.'
    end

    # Verifies the key by creating an address — the one authenticated call
    # that works in both modes. Account-management endpoints
    # (`carrier_account.all`, `api_key.all`) are production-only and reject a
    # valid test key with "This resource requires a production API Key",
    # which would block merchants from connecting a test key at all.
    # Addresses are inert: no shipment, no charge, nothing to clean up.
    #
    # Rescues broadly, not just SDK errors — a DNS failure or timeout must
    # surface as a clean activation error, never a 500.
    def can_connect?
      client.address.create(VERIFICATION_ADDRESS)
      true
    rescue StandardError => e
      self.connection_error_message = e.message
      false
    end

    # @return [EasyPost::Client]
    def client
      @client ||= EasyPost::Client.new(api_key: preferred_api_key)
    end
  end
end
