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

    # A cheap authenticated read: fails with 401 on a bad key without
    # creating anything on the account.
    def can_connect?
      client.carrier_account.all
      true
    rescue EasyPost::Errors::EasyPostError => e
      self.connection_error_message = e.message
      false
    end

    # @return [EasyPost::Client]
    def client
      @client ||= EasyPost::Client.new(api_key: preferred_api_key)
    end
  end
end
