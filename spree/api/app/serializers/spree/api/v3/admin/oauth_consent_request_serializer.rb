module Spree
  module Api
    module V3
      module Admin
        # Admin API serializer for {Spree::OauthConsentRequest}.
        #
        # Alba directly rather than through {BaseSerializer}: a consent
        # request is a computed view with no id to expose, and inheriting one
        # would put a null `id` in every response.
        class OauthConsentRequestSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize client_name: :string,
                   scopes: [:string, multi: true],
                   grantable_scopes: [:string, multi: true],
                   resource: [:string, nullable: true],
                   redirect_uri: :string

          attributes :client_name, :scopes, :grantable_scopes, :resource, :redirect_uri
        end
      end
    end
  end
end
