module Spree
  module Api
    module V3
      module Seller
        # A pending invitation to join this seller.
        #
        # Only what the inviting seller needs to see: who was invited, whether
        # they have accepted, and when it lapses. The shared serializer's
        # polymorphic fields (`resource_type`, `inviter_id`, `role_id`) describe
        # plumbing the seller cannot act on — and the invitation is always to
        # the seller whose panel they are already looking at.
        class InvitationSerializer < V3::BaseSerializer
          typelize email: :string, status: :string,
                   expires_at: [:string, nullable: true],
                   accepted_at: [:string, nullable: true]

          attributes :email, created_at: :iso8601

          attribute :status do |invitation|
            invitation.status.to_s
          end

          attribute :expires_at do |invitation|
            invitation.expires_at&.iso8601
          end

          attribute :accepted_at do |invitation|
            invitation.accepted_at&.iso8601
          end
        end
      end
    end
  end
end
