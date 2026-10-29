require 'net/http'

module SpreePaypalCheckout
  # The PayPal calls the SDK does not cover: webhook signature verification and
  # webhook registration under /v1/notifications. None of them moves money; a
  # failed verification is redelivered by PayPal and a failed registration is
  # retried by its job, so short timeouts and no retries are enough.
  class NotificationsClient
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10
    # Raised by Net::HTTP when PayPal cannot be reached or does not answer.
    NETWORK_ERRORS = [
      Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, SocketError, EOFError, OpenSSL::SSL::SSLError,
      Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ETIMEDOUT
    ].freeze

    # PayPal answered with an error status.
    class Error < StandardError; end

    # @param gateway [SpreePaypalCheckout::Gateway]
    def initialize(gateway)
      @gateway = gateway
    end

    # The event is sent as PayPal delivered it, byte for byte: re-encoding it
    # can change how numbers and characters are written.
    #
    # @param raw_body [String] the delivery's body, already known to be JSON
    # @return [String] PayPal's verdict, SUCCESS or FAILURE
    def verify_webhook_signature(raw_body:, headers:, webhook_id:)
      fields = headers.merge(webhook_id: webhook_id).to_json
      body = "#{fields.delete_suffix('}')},\"webhook_event\":#{raw_body}}"

      request(Net::HTTP::Post, '/v1/notifications/verify-webhook-signature', body)['verification_status']
    end

    # @return [Array<Hash>] every webhook of the REST app the credentials belong to
    def list_webhooks
      Array(request(Net::HTTP::Get, '/v1/notifications/webhooks')['webhooks'])
    end

    # @return [Hash] the created webhook
    def create_webhook(url:, event_types:)
      body = { url: url, event_types: event_types.map { |name| { name: name } } }.to_json
      request(Net::HTTP::Post, '/v1/notifications/webhooks', body)
    end

    # @return [Hash] the updated webhook
    def replace_webhook_events(webhook_id, event_types)
      body = [{ op: 'replace', path: '/event_types', value: event_types.map { |name| { name: name } } }].to_json
      request(Net::HTTP::Patch, "/v1/notifications/webhooks/#{webhook_id}", body)
    end

    private

    attr_reader :gateway

    def request(verb, path, body = nil)
      uri = URI.join(gateway.client.config.get_base_uri, path)
      http_request = verb.new(uri)
      http_request['Authorization'] = "Bearer #{access_token}"
      http_request['Content-Type'] = 'application/json'
      http_request['Accept'] = 'application/json'
      http_request.body = body if body

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                 open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(http_request)
      end

      parsed = response.body.present? ? JSON.parse(response.body) : {}
      return parsed if response.is_a?(Net::HTTPSuccess)

      raise Error, "PayPal answered #{response.code}: #{[parsed['name'], parsed['message']].compact.join(' — ')}"
    end

    # From the SDK's own OAuth client, so token handling lives in one place.
    def access_token
      @access_token ||= gateway.request_access_token.access_token
    end
  end
end
