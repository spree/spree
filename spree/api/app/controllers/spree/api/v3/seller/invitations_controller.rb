module Spree
  module Api
    module V3
      module Seller
        # Invitations this seller has sent that nobody has accepted yet.
        #
        # Separate from `TeamController` because they are different things: a
        # member is a person who can sign in, an invitation is an offer that
        # may lapse. Creating one still belongs to the team endpoint — hiring
        # is what the seller is doing — while chasing or withdrawing one is
        # bookkeeping on the offer itself.
        #
        # Rooted at `current_seller.invitations` throughout, so a seller can
        # neither see nor touch an invitation sent by anyone else.
        class InvitationsController < Seller::BaseController
          scoped_resource :seller_profile

          before_action :set_invitation, only: [:destroy, :resend]

          # Pending only: an accepted invitation is a team member, and the
          # panel already lists those.
          def index
            invitations = current_seller.invitations.pending.order(created_at: :desc)

            render json: { data: invitations.map { |invitation| serialize(invitation) } }
          end

          # Withdraws an offer that has not been accepted.
          def destroy
            @invitation.destroy
            head :no_content
          end

          # Sends the invitation email again, for a colleague who never got
          # the first one. The model refuses once the invitation has expired
          # or been accepted, and says so rather than silently doing nothing.
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

          def set_invitation
            @invitation = current_seller.invitations.pending.find_by_prefix_id!(params[:id])
          end

          def serialize(invitation)
            Spree.api.seller_invitation_serializer.new(
              invitation, params: { store: current_store }
            ).to_h
          end
        end
      end
    end
  end
end
