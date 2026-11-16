module SpreeAdyen
  # Puts a payment method's credential and webhook in the state the gem needs:
  # a client key, the store's allowed origins, and a merchant-level webhook on
  # the method's own URL, signed with a key Spree holds.
  #
  # Safe to run again: everything already in place is found and kept.
  class Configure
    # @param gateway [SpreeAdyen::Gateway]
    def self.call(gateway)
      new(gateway).call
    end

    def initialize(gateway)
      @gateway = gateway
    end

    # @return [SpreeAdyen::Gateway]
    def call
      credential = gateway.adyen_call(:read_credential) { |client| client.management.my_api_credential_api.get_api_credential_details }
      client_key = credential['clientKey'].presence || generate_client_key
      add_allowed_origins(credential)
      webhook_id = put_webhook

      if gateway.preferred_hmac_key.blank? || webhook_id != gateway.preferred_webhook_id
        gateway.preferred_previous_hmac_key = gateway.preferred_hmac_key if gateway.preferred_hmac_key.present?
        gateway.preferred_hmac_key = generate_hmac_key(webhook_id)
      end
      gateway.preferred_client_key = client_key
      gateway.preferred_webhook_id = webhook_id
      gateway.save!
      gateway
    end

    private

    attr_reader :gateway

    def merchant_account
      gateway.preferred_merchant_account
    end

    # Never replaced: a new key retires the old one after 24 hours, and other
    # stores sharing the credential would stop loading Drop-in.
    def generate_client_key
      gateway.adyen_call(:generate_client_key) { |client| client.management.my_api_credential_api.generate_client_key }['clientKey']
    end

    # Drop-in loads only on the credential's allowed origins. Loopback ones
    # are left out: Adyen refuses them.
    def add_allowed_origins(credential)
      listed = Array(credential['allowedOrigins']).pluck('domain')

      gateway.store.allowed_origins.reject(&:loopback?).map(&:origin).each do |origin|
        next if listed.include?(origin)

        begin
          gateway.adyen_call(:add_allowed_origin) do |client|
            client.management.my_api_credential_api.add_allowed_origin({ domain: origin })
          end
        rescue Spree::Core::GatewayError => error
          raise unless error.message.match?(/already exists/i)
        end
      end
    end

    # A webhook this method created before, pointing elsewhere (5.x's
    # /adyen/webhooks), is moved in place: it keeps its HMAC key and delivers
    # what Adyen queued for it. Otherwise the merchant's standard webhook for
    # the URL is found, or one is created.
    #
    # @return [String] the webhook id
    def put_webhook
      stored = stored_webhook
      if stored
        update_webhook_url(stored) if stored['url'] != gateway.webhook_url
        return stored['id']
      end

      found = Array(list_webhooks['data']).find { |webhook| webhook['type'] == 'standard' && webhook['url'] == gateway.webhook_url }
      return found['id'] if found

      gateway.adyen_call(:create_webhook) do |client|
        client.management.webhooks_merchant_level_api.set_up_webhook(
          { type: 'standard', url: gateway.webhook_url, active: true, communicationFormat: 'json' }, merchant_account
        )
      end['id']
    end

    def stored_webhook
      return if gateway.preferred_webhook_id.blank?

      gateway.adyen_call(:read_webhook) do |client|
        client.management.webhooks_merchant_level_api.get_webhook(merchant_account, gateway.preferred_webhook_id)
      end
    rescue Spree::Core::GatewayError => error
      raise unless error.message.match?(/not found/i)
    end

    def update_webhook_url(webhook)
      gateway.adyen_call(:update_webhook) do |client|
        client.management.webhooks_merchant_level_api.update_webhook({ url: gateway.webhook_url }, merchant_account, webhook['id'])
      end
    end

    def list_webhooks
      gateway.adyen_call(:list_webhooks) do |client|
        client.management.webhooks_merchant_level_api.list_all_webhooks(merchant_account, query_params: { pageSize: 100 })
      end
    end

    def generate_hmac_key(webhook_id)
      gateway.adyen_call(:generate_hmac_key) do |client|
        client.management.webhooks_merchant_level_api.generate_hmac_key(merchant_account, webhook_id)
      end['hmacKey']
    end
  end
end
