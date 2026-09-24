module Spree
  module Api
    module V3
      module Admin
        module Sellers
          module Invitations
            # The acceptance link of a pending invitation onto a seller's team.
            #
            # The link carries the token that joins the team, so reading
            # sellers is not enough: the caller must be able to change the
            # seller, as when sending the invitation.
            class AcceptanceLinksController < Admin::BaseController
              scoped_resource :sellers

              # GET /api/v3/admin/sellers/:seller_id/invitations/:invitation_id/acceptance_link
              def show
                seller = current_store.sellers.find_by_prefix_id!(params[:seller_id])
                authorize!(:update, seller)
                invitation = seller.invitations.pending.find_by_prefix_id!(params[:invitation_id])

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
end
