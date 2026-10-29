module Spree
  module Api
    module V3
      module Seller
        class InvitationSerializer < V3::BaseSerializer
          typelize email: :string, status: [:string, enum: Spree::Invitation.statuses, enum_type_name: 'InvitationStatus'],
                   expires_at: [:string, nullable: true],
                   accepted_at: [:string, nullable: true],
                   inviter_email: :string,
                   invitee_exists: :boolean,
                   seller: '{ id: string; name: string }'

          attributes :email,
                     created_at: :iso8601, expires_at: :iso8601, accepted_at: :iso8601

          attributes status: :string

          attribute :inviter_email do |invitation|
            invitation.inviter.email
          end

          # Drives the acceptance page's sign-in vs sign-up branch, as on the
          # admin serializer.
          attribute :invitee_exists do |invitation|
            Spree.admin_user_class.exists?(email: invitation.email)
          end

          # The smallest shape the acceptance page's title ("Join <seller>")
          # needs; the page is public, so nothing more of the seller goes out.
          attribute :seller do |invitation|
            { id: invitation.resource.prefixed_id, name: invitation.resource.name }
          end
        end
      end
    end
  end
end
