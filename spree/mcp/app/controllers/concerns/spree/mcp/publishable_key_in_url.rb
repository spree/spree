module Spree
  module Mcp
    # Lets a Store API endpoint take its publishable key from the URL.
    #
    # An MCP client is configured with a URL and often nothing else, and a
    # UCP profile advertises the endpoint as one URL, so the key has to be
    # able to ride in it. Publishable keys are public by design — the same key
    # ships in every storefront's JavaScript.
    module PublishableKeyInUrl
      extend ActiveSupport::Concern

      protected

      def extract_api_key
        super || request.query_parameters['key'].presence
      end

      # The inherited refusal is a REST error body. An MCP client shows
      # whatever a JSON-RPC error says, so a JSON-RPC call is told how to fix
      # it in that form.
      def authenticate_api_key!
        return super if publishable_api_key.present? || !request.post?

        render json: {
          jsonrpc: '2.0',
          id: nil,
          error: {
            code: -32_000,
            message: "This address needs the store's publishable API key. Add it as " \
                     '?key=pk_… or send it in the X-Spree-API-Key header.'
          }
        }, status: :unauthorized
        false
      end

      # This endpoint's address as a client should be given it: the key the
      # request authenticated with, carried in the URL. The configured public
      # origin wins over the one the request arrived on, which is a private
      # address whenever a storefront fetches the profile on an internal
      # network.
      #
      # @return [String]
      def store_mcp_url
        origin = Spree::Config[:public_api_url].presence&.chomp('/') || request.base_url
        "#{origin}/api/v3/store/mcp?#{{ key: current_api_key.token }.to_query}"
      end
    end
  end
end
