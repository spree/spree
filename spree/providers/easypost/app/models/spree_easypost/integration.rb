module SpreeEasyPost
  # Per-store EasyPost credentials. The API key decides the mode — EasyPost
  # issues separate test and production keys, so there is no mode toggle.
  class Integration < Spree::Integration
    preference :api_key, :password

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

    def self.integration_name
      'EasyPost'
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
