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

          # A public discovery document, read before any credential exists.
          # The module has to be included because `ActionController::API`
          # carries none of it; `:exception` is free here because the only
          # action is a GET, which forgery protection never applies to.
          include ActionController::RequestForgeryProtection
          protect_from_forgery with: :exception

          # The `resource` value must equal the URL the client was pointed at,
          # path and all, or a consumer client refuses to continue — so it is
          # built from this request's own origin rather than from anything
          # configured elsewhere.
          def show
            resource = Spree::Api::Oauth.resource_identifier(params[:resource_key], request.base_url)
            return head :not_found if resource.blank?

            render json: {
              resource: resource,
              authorization_servers: [issuer],
              # Exactly what the authorization server will accept.
              #
              # The spec tells a client with no scope challenge to request
              # everything advertised here, and Doorkeeper refuses a request
              # naming a scope it does not know — so advertising one more
              # than it accepts turns every connection into "The requested
              # scope is invalid".
              scopes_supported: Spree::Api::Oauth.staff_scope_keys,
              bearer_methods_supported: ['header'],
              resource_documentation: 'https://spreecommerce.org/docs/developer/agentic/admin-mcp'
            }
          end

          private

          # The authorization server's own origin. This request reached it, so
          # the origin it arrived on is the one a client can use.
          def issuer
            ::Doorkeeper.config.issuer.presence || request.base_url
          end
        end
      end
    end
  end
end
