module Spree
  module Api
    module V3
      module Admin
        # The least a whole order must come to under a catalog's agreement,
        # in one currency.
        class CatalogOrderMinimumSerializer < V3::BaseSerializer
          typelize currency: :string

          attributes :currency, created_at: :iso8601, updated_at: :iso8601

          money_attributes :amount, :display_amount
          typelize amount: [:string, nullable: false], display_amount: [:string, nullable: false]
        end
      end
    end
  end
end
