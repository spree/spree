module Spree
  module Api
    module V3
      module Admin
        class MarketSerializer < V3::MarketSerializer
          typelize tax_provider: [:string, nullable: true]

          # Which tax engine computes for this market. Nil means the store-wide
          # default; the selectable values come from /admin/tax_providers.
          attributes :tax_provider, created_at: :iso8601, updated_at: :iso8601

          many :countries,
               resource: proc { Spree.api.admin_country_serializer },
               if: proc { expand?(:countries) }
        end
      end
    end
  end
end
