module Spree
  module Api
    module V3
      module Seller
        class InvitationSerializer < V3::BaseSerializer
          typelize email: :string, status: :string,
                   expires_at: [:string, nullable: true],
                   accepted_at: [:string, nullable: true],
                   acceptance_url: :string

          attributes :email,
                     created_at: :iso8601, expires_at: :iso8601, accepted_at: :iso8601

          attribute :status do |invitation|
            invitation.status.to_s
          end

          attribute :acceptance_url do |invitation|
            if Spree::Config[:seller_panel_url].present? || Spree::Config[:dashboard_url].present?
              Rails.application.routes.url_helpers.admin_invitation_acceptance_url(invitation)
            else
              "/accept-invitation/#{invitation.prefixed_id}?token=#{invitation.token}"
            end
          end
        end
      end
    end
  end
end
