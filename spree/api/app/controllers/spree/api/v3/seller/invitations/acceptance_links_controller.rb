module Spree
  module Api
    module V3
      module Seller
        module Invitations
          # The acceptance link of a pending invitation onto this seller's team.
          #
          # The link carries the token that joins the team, so it is authorized
          # like inviting someone: write access to the seller profile. Rooted at
          # `current_seller.invitations`, so another seller's invitation reads
          # as missing.
          class AcceptanceLinksController < Seller::BaseController
            scoped_resource :seller_profile

            # GET /api/v3/seller/invitations/:invitation_id/acceptance_link
            def show
              invitation = current_seller.invitations.pending.find_by_prefix_id!(params[:invitation_id])

              render json: Spree.api.seller_invitation_acceptance_link_serializer.new(
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
