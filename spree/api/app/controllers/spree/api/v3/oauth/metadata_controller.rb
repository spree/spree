module Spree
  module Api
    module V3
      module Oauth
        # RFC 9728 Protected Resource Metadata — the one discovery document
        # Doorkeeper does not ship (it serves RFC 8414 authorization-server
        # metadata itself).
        #
        # A client reads this to learn which authorization server guards a
        # resource. It is deliberately unauthenticated: a client has no
        # credential at the point it asks.
        class MetadataController < ActionController::API
          include Spree::Core::ControllerHelpers::Store

          # A public discovery document, read before any credential exists.
          # The module has to be included because `ActionController::API`
          # carries none of it; `:exception` is free here because the only
          # action is a GET, which forgery protection never applies to.
          include ActionController::RequestForgeryProtection
          protect_from_forgery with: :exception

          # The `resource` value must equal the URL the client was pointed at,
          # path and all, or a consumer client refuses to continue — so it is
          # echoed from the registered identifier rather than rebuilt here.
          def show
            resource = Spree::Api::Oauth.resource_identifier(params[:resource_key], current_store)
            return head :not_found if resource.blank?

            render json: {
              resource: resource,
              authorization_servers: [issuer],
              # Staff keys only: a grant acts for an admin user, so a
              # seller-only key could never be exercised through it.
              scopes_supported: Spree.permissions.grantable_keys(
                Spree::PermissionConfiguration::STAFF_AUDIENCE
              ),
              bearer_methods_supported: ['header'],
              resource_documentation: 'https://spreecommerce.org/docs/developer/agentic/admin-mcp'
            }
          end

          private

          def issuer
            ::Doorkeeper.config.issuer.presence || current_store.formatted_url
          end
        end
      end
    end
  end
end
