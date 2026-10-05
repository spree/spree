module Spree
  module Seeds
    # Pre-registers the consumer MCP clients.
    #
    # Hosted connectors cannot register themselves: dynamic client
    # registration is deprecated in the current MCP revision, and client ID
    # metadata documents are not yet supported by the authorization server.
    # Pre-registration is the first option in the spec's own priority order,
    # and it means a merchant pastes their store URL into the client and signs
    # in — nothing to create first.
    class OauthApplications
      prepend Spree::ServiceModule::Base
      include StoreScoped

      # Each client's own documented callback. A redirect URI is the one thing
      # that cannot be guessed at runtime, so it is registered rather than
      # accepted from the request.
      CLIENTS = [
        {
          name: 'Claude',
          redirect_uri: 'https://claude.ai/api/mcp/auth_callback'
        },
        {
          name: 'ChatGPT',
          redirect_uri: 'https://chatgpt.com/connector_platform_oauth_redirect'
        }
      ].freeze

      private

      def seed(store)
        CLIENTS.each do |client|
          next if store.oauth_applications.exists?(name: client[:name])

          store.oauth_applications.create!(
            name: client[:name],
            redirect_uri: client[:redirect_uri],
            # Public: a hosted connector runs on the vendor's servers and
            # cannot keep a secret, which is why PKCE is mandatory.
            confidential: false,
            # Granted at consent, not at registration — the merchant decides
            # what a client may do, and may re-consent to change it.
            scopes: ''
          )
        end
      end
    end
  end
end
