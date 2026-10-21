module Spree
  module Api
    module V3
      module Store
        # The store's UCP business profile: `GET /api/v3/store/ucp_profile`.
        #
        # What an agent reads at a merchant's `/.well-known/ucp` to find the
        # shopping endpoint and the capabilities it implements. The storefront
        # serves this document at that path on its own domain.
        class UcpProfilesController < Store::BaseController
          include Spree::Mcp::PublishableKeyInUrl

          def show
            render json: Spree::AgentTools::Shopping::Ucp.profile(endpoint: store_mcp_url)
          end
        end
      end
    end
  end
end
