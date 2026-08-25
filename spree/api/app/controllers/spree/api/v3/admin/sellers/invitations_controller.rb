module Spree
  module Api
    module V3
      module Admin
        module Sellers
          # Offers to join one of the marketplace's sellers that nobody has
          # accepted yet.
          #
          # The operator's counterpart to the seller panel's own invitations
          # endpoint, and rooted the same way — at the seller's invitations, so
          # an id from another seller reads as missing rather than as denied.
          #
          # Creating one is the `invite` action on the seller itself; what is
          # here is the bookkeeping the operator needs when an offer went to
          # the wrong address or never arrived.
          class InvitationsController < Admin::BaseController
            scoped_resource :sellers

            before_action :set_seller
            before_action :set_invitation, only: [:destroy, :resend]

            # Pending only: an accepted invitation is a team member, which the
            # team endpoint lists.
            def index
              invitations = @seller.invitations.pending.order(created_at: :desc)

              render json: { data: invitations.map { |invitation| serialize(invitation) } }
            end

            def destroy
              @invitation.destroy
              head :no_content
            end

            # Sends the email again. The model refuses once the invitation has
            # expired, and says so rather than silently doing nothing.
            def resend
              if @invitation.expired?
                return render_error(
                  code: ErrorHandler::ERROR_CODES[:processing_error],
                  message: Spree.t(:invitation_expired),
                  status: :unprocessable_content
                )
              end

              @invitation.resend!
              render json: serialize(@invitation)
            end

            protected

            def read_actions
              %w[index]
            end

            private

            def set_seller
              @seller = current_store.sellers.find_by_prefix_id!(params[:seller_id])
              authorize! :show, @seller
            end

            def set_invitation
              @invitation = @seller.invitations.pending.find_by_prefix_id!(params[:id])
            end

            def serialize(invitation)
              Spree.api.admin_invitation_serializer.new(
                invitation, params: { store: current_store }
              ).to_h
            end
          end
        end
      end
    end
  end
end
