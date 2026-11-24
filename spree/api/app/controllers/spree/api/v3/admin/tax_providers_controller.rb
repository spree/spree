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

          # A shorter query matches too much of a catalogue to be worth asking for.
          MIN_TAX_CODE_QUERY_LENGTH = 2

          # GET /api/v3/admin/tax_providers
          def index
            render json: { data: Spree.tax_providers.map { |provider| provider.to_api_hash(current_store) } }
          end

          # GET /api/v3/admin/tax_providers/:id/tax_codes?q=
          #
          # Searches an engine's own tax codes for the tax category form. An
          # engine with no catalogue answers an empty list rather than an error,
          # so the form can ask any engine in use.
          def tax_codes
            authorize! :read, Spree::TaxCategory

            provider = Spree::ApiTyped.find(Spree.tax_providers, params[:id])
            raise ActiveRecord::RecordNotFound unless provider

            query = params[:q].to_s.strip
            codes = query.length >= MIN_TAX_CODE_QUERY_LENGTH ? Array(provider.tax_codes(current_store, query: query)) : []

            render json: { data: codes.map { |code| { code: code[:code].to_s, description: code[:description].to_s } } }
          end
        end
      end
    end
  end
end
