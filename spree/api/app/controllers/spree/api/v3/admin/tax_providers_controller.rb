module Spree
  module Api
    module V3
      module Admin
        # Which tax engines this installation can point a market at, and what
        # each of them cannot do. Discovery rather than CRUD: providers are
        # classes registered in code, not rows — so there is no serializer, and
        # each class describes itself (`to_api_hash`), the same shape
        # `/promotion_rules/types` and `/collection_rules/types` use.
        #
        # The capability list is the point — a merchant selling into US states
        # needs to be told at configuration time that the built-in engine has no
        # local-tax data, rather than discovering it from a tax bill.
        class TaxProvidersController < BaseController
          scoped_resource :settings

          # GET /api/v3/admin/tax_providers
          def index
            render json: { data: Spree.tax_providers.map { |provider| provider.to_api_hash(current_store) } }
          end
        end
      end
    end
  end
end
