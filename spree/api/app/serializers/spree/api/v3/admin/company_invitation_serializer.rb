module Spree
  module Api
    module V3
      module Admin
        class CompanyInvitationSerializer < V3::CompanyInvitationSerializer
          typelize accepted_at: [:string, nullable: true],
                   revoked_at: [:string, nullable: true]

          attributes accepted_at: :iso8601, revoked_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
