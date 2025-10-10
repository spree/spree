require 'base64'
require 'openssl'

module Spree
  module Webhooks
    class EventSignature
      def initialize(event, payload)
        @event = event
        @payload = payload
      end

      # Generates a base64-encoded HMAC SHA256 signature for the payload of the event.
      #
      # By using the stringified payload, the signature is made tamper-proof as any
      # alterations of the data during transit will lead to an incorrect signature
      # comparison by the client.
      #
      # @return [String] The computed signature
      def computed_signature
        @computed_signature ||=
          Base64.strict_encode64(
            OpenSSL::HMAC.digest('sha256', @event.subscriber.secret_key, payload)
          )
      end

      private

      def payload
        @payload.is_a?(String) ? @payload : @payload.to_json
      end
    end
  end
end
