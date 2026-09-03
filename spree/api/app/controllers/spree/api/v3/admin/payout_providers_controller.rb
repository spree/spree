module Spree
  module Api
    module V3
      module Admin
        # How this installation can pay its sellers, and which of those a store
        # could use today.
        #
        # Discovery rather than CRUD: providers are classes registered in code,
        # not rows — so there is no serializer, and each class describes itself
        # (`to_api_hash`), the same shape `/tax_providers` uses.
        #
        # Whether a provider needs sellers to hold an account with it is the
        # part worth surfacing at selection time: choosing one changes what a
        # marketplace has to ask of its sellers before it can pay them, which
        # is better known before the choice than after.
        class PayoutProvidersController < BaseController
          scoped_resource :settings

          # GET /api/v3/admin/payout_providers
          def index
            render json: { data: Spree.payout_providers.map { |provider| provider.to_api_hash(current_store) } }
          end
        end
      end
    end
  end
end
