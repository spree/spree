module Spree
  module Api
    module V3
      module Admin
        # Admin-only: exemption reasons are recorded on certificates, which are
        # back-office evidence with no storefront surface.
        class TaxExemptionReasonSerializer < V3::BaseSerializer
          typelize name: :string, code: :string, active: :boolean, can_be_deleted: :boolean,
                   metadata: 'Record<string, unknown> | null'

          attributes :name, :code, :active, :metadata, created_at: :iso8601, updated_at: :iso8601

          # Lets the dashboard hide destructive controls instead of offering a
          # delete that the model will refuse.
          attribute :can_be_deleted, &:can_be_deleted?
        end
      end
    end
  end
end
