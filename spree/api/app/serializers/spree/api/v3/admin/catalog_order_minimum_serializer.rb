module Spree
  module Api
    module V3
      module Admin
        # The least a whole order must come to under a catalog's agreement,
        # in one currency.
        class CatalogOrderMinimumSerializer < V3::BaseSerializer
          typelize currency: :string, amount: :string, display_amount: :string

          attributes :currency, created_at: :iso8601, updated_at: :iso8601

          attribute :amount do |minimum|
            minimum.amount.to_s
          end

          attribute :display_amount do |minimum|
            minimum.display_amount.to_s
          end
        end
      end
    end
  end
end
