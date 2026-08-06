module SpreeEasyPost
  # Per-store EasyPost credentials. The API key decides the mode — EasyPost
  # issues separate test and production keys, so there is no mode toggle.
  class Integration < Spree::Integration
    preference :api_key, :password

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

    # A cheap authenticated read: fails with 401 on a bad key without
    # creating anything on the account.
    # Rescues broadly, not just SDK errors — a DNS failure or timeout must
    # surface as a clean activation error, never a 500.
    def can_connect?
      client.carrier_account.all
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
