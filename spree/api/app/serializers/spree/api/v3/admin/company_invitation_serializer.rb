module Spree
  module Api
    module V3
      module Admin
        class CompanyInvitationSerializer < V3::CompanyInvitationSerializer
          typelize accepted_at: [:string, nullable: true],
                   revoked_at: [:string, nullable: true]

          attributes accepted_at: :iso8601, revoked_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          one :company, resource: proc { Spree.api.admin_company_serializer }, if: proc { expand?('company') }

          # Only the Store API's token lookup sends these.
          _attributes.delete_if { |key, _| %i[company_name store_name].include?(key.to_sym) }
        end
      end
    end
  end
end
