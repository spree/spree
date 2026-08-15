module Spree
  module Api
    module V3
      module Admin
        class TaxLineSerializer < V3::TaxLineSerializer
          typelize amount: [:string, nullable: false], display_amount: [:string, nullable: false],
                   provider_id: [:string, nullable: true], metadata: ['Record<string, unknown>', nullable: true],
                   taxability_reason: [:string, nullable: true], country_code: [:string, nullable: true],
                   state_code: [:string, nullable: true], data: ['Record<string, unknown>', nullable: true]

          # The treatment and its jurisdiction stay admin-only: no surveyed
          # platform shows a buyer a machine-readable tax reason, and `label`
          # already covers what they need. `data` carries the provider's own
          # breakdown, which is what an e-invoicing integration reads.
          attributes :provider_id, :metadata, :taxability_reason, :country_code, :state_code, :data,
                     created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
