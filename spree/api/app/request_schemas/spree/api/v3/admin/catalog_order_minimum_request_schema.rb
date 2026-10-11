module Spree
  module Api
    module V3
      module Admin
        # The least a whole order must come to under a catalog, in one currency.
        class CatalogOrderMinimumRequestSchema < Spree::Api::V3::RequestSchema
          publishes 'CatalogOrderMinimumParams'

          currency :currency, example: 'USD', description: 'ISO 4217 code. Required on create; one minimum per currency.'
          decimal :amount, example: '500.00'
        end
      end
    end
  end
end
