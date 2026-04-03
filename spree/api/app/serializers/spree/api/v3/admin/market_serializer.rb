module Spree
  module Api
    module V3
      module Admin
        class MarketSerializer < V3::MarketSerializer
          attributes created_at: :iso8601, updated_at: :iso8601

          many :countries,
               resource: Spree.api.admin_country_serializer,
               if: proc { expand?(:countries) }
        end
      end
    end
  end
end
