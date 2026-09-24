module Spree
  module Api
    module V3
      module Seller
        class InvitationSerializer < V3::BaseSerializer
          typelize email: :string, status: [:string, enum: Spree::Invitation.statuses, enum_type_name: 'InvitationStatus'],
                   expires_at: [:string, nullable: true],
                   accepted_at: [:string, nullable: true]

          attributes :email,
                     created_at: :iso8601, expires_at: :iso8601, accepted_at: :iso8601

          attribute :status do |invitation|
            invitation.status.to_s
          end
        end
      end
    end
  end
end
