module Spree
  module Api
    module V3
      module Admin
        class TaxLineSerializer < V3::TaxLineSerializer
          typelize amount: [:string, nullable: false], display_amount: [:string, nullable: false],
                   provider_id: [:string, nullable: true], metadata: ['Record<string, unknown>', nullable: true]

          attributes :provider_id, :metadata, created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
