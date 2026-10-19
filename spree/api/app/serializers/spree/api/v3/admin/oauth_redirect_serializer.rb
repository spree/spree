module Spree
  module Api
    module V3
      module Admin
        # Admin API serializer for {Spree::OauthRedirect}.
        class OauthRedirectSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize redirect_uri: :string

          attributes :redirect_uri
        end
      end
    end
  end
end
