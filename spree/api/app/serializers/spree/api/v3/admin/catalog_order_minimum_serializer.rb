module Spree
  module Api
    module V3
      module Admin
        # The least a whole order must come to under a catalog's agreement,
        # in one currency.
        class CatalogOrderMinimumSerializer < V3::BaseSerializer
          typelize currency: :string, amount: :string, display_amount: :string

          attributes :currency, created_at: :iso8601, updated_at: :iso8601

          attributes amount: :string, display_amount: :string
        end
      end
    end
  end
end
