module Spree
  module Api
    module V3
      module Admin
        # Serializer for {Spree::OauthProtectedResource}, the RFC 9728
        # document a client reads to find the authorization server.
        #
        # Alba directly rather than through {BaseSerializer}: the document is
        # a computed view with no id, and inheriting one would put a null
        # `id` in a document the spec defines exactly.
        class OauthProtectedResourceSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize resource: :string,
                   authorization_servers: [:string, multi: true],
                   scopes_supported: [:string, multi: true],
                   bearer_methods_supported: [:string, multi: true],
                   resource_documentation: :string

          attributes :resource, :authorization_servers, :scopes_supported,
                     :bearer_methods_supported, :resource_documentation
        end
      end
    end
  end
end
