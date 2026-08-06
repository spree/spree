module Spree
  module Api
    module V3
      module Admin
        # Which tax engines this installation can point a market at, and what
        # each of them cannot do. Discovery rather than CRUD: providers are
        # classes registered in code, not rows.
        #
        # The capability list is the point — a merchant selling into US states
        # needs to be told at configuration time that the built-in engine has no
        # local-tax data, rather than discovering it from a tax bill.
        class TaxProvidersController < BaseController
          scoped_resource :settings

          # GET /api/v3/admin/tax_providers
          def index
            render json: { data: Spree.tax_providers.map { |provider| serialize_provider(provider) } }
          end

          private

          def serialize_provider(provider)
            {
              id: provider.to_s,
              name: provider.to_s.demodulize.titleize,
              available: provider.available_for_store?(current_store),
              unsupported_capabilities: provider.unsupported_capabilities.map(&:to_s),
              default: provider.to_s == Rails.application.config.spree.tax_provider.to_s
            }
          end
        end
      end
    end
  end
end
