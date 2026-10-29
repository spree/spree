module Spree
  module Api
    module V3
      module Seller
        class InvitationSerializer < V3::BaseSerializer
          typelize email: :string, status: [:string, enum: Spree::Invitation.statuses, enum_type_name: 'InvitationStatus'],
                   expires_at: [:string, nullable: true],
                   accepted_at: [:string, nullable: true],
                   inviter_email: :string,
                   invitee_exists: [:boolean, optional: true],
                   seller: '{ id: string; name: string }'

          attributes :email,
                     created_at: :iso8601, expires_at: :iso8601, accepted_at: :iso8601

          attributes status: :string

          attribute :inviter_email do |invitation|
            invitation.inviter.email
          end

          # Drives the acceptance page's sign-in vs sign-up branch, so only the
          # public lookup carries it: whoever holds the emailed link already
          # knows the address. A seller's team screen does not get to learn
          # which addresses hold accounts elsewhere on the marketplace.
          attribute :invitee_exists, if: proc { params[:acceptance] } do |invitation|
            invitation.invitee_account.present?
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
