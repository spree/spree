module Spree
  module Api
    module V3
      module Admin
        class MarketSerializer < V3::MarketSerializer
          typelize tax_provider: [:string, nullable: true, comment: 'Tax provider; null uses the store default. Built-in: internal, recorded_share. Provider gems register more.']

          attributes created_at: :iso8601, updated_at: :iso8601

          # Which tax engine computes for this market. Nil means the store-wide
          # default; the selectable values come from /admin/tax_providers.
          api_type_attributes :tax_provider

          many :countries,
               resource: proc { Spree.api.admin_country_serializer },
               if: proc { expand?(:countries) }
        end
      end
    end
  end
end
