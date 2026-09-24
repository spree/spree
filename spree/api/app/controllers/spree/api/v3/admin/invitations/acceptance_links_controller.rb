module Spree
  module Api
    module V3
      module Admin
        module Invitations
          # The acceptance link of a pending staff invitation.
          #
          # The link carries the token that creates the account and grants the
          # role, so it is authorized like sending the invitation: the caller
          # needs write access to staff and must be allowed to grant the
          # invitation's role. Reading staff is not enough.
          class AcceptanceLinksController < Admin::BaseController
            include Spree::Api::V3::Admin::RoleGrantGuard

            scoped_resource :staff

            # GET /api/v3/admin/invitations/:invitation_id/acceptance_link
            def show
              invitation = Spree::Invitation.
                           where(resource: current_store).
                           pending.
                           find_by_prefix_id!(params[:invitation_id])
              authorize!(:update, invitation)
              return if reject_unauthorized_role_grant!([invitation.role_id])

              render json: Spree.api.admin_invitation_acceptance_link_serializer.new(
                invitation, params: { store: current_store }
              ).to_h
            end

            protected

            def read_actions
              []
            end
          end
        end
      end
    end
  end
end
