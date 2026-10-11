module Spree
  module Api
    module V3
      module Admin
        module Oauth
          # Connected applications, so a merchant can see which agents and
          # apps hold access to the store and take it away.
          #
          # Revoking is the off switch and has to be immediate: it revokes
          # every live token and grant rather than deleting the registration,
          # so a client that still holds a token stops working on its next
          # call.
          class ApplicationsController < Spree::Api::V3::Admin::ResourceController
            # Its own permission rather than store configuration: a standing
            # credential to the back office is not the same kind of thing as
            # a delivery zone.
            scoped_resource :oauth_applications

            # `confidential` is not settable: these are hosted connectors that
            # cannot keep a secret, which is why PKCE is mandatory. Neither is
            # `scopes` — what a client may do is granted by the merchant at
            # consent, not fixed at registration.
            request_params :oauth_application do |body|
              body.attribute :name, :string, required: true, example: 'Claude'
              body.attribute :redirect_uri, :string,
                description: 'Where the authorization server sends the browser back to.',
                example: 'https://claude.ai/api/mcp/auth_callback'
            end

            protected

            def model_class
              Spree::OauthApplication
            end

            def serializer_class
              Spree.api.admin_oauth_application_serializer
            end

            def scope
              super.order(:name)
            end

            # The serializer reads each application's scopes, last
            # authorization and who approved it from the live tokens.
            def collection_includes
              { live_access_tokens: :resource_owner }
            end

          end
        end
      end
    end
  end
end
