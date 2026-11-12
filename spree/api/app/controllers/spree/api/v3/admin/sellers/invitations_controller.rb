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
          # Creating one here adds someone to the team and leaves the seller's
          # status alone, so it works for a seller already trading. The
          # `invite` action on the seller is the lifecycle step that opens a
          # pending seller for its first owner.
          class InvitationsController < Admin::BaseController
            scoped_resource :sellers

            before_action :set_seller
            # Every write hands out or withdraws a way onto the team, so it
            # needs the same right as changing the seller.
            before_action :authorize_seller_update, only: [:create, :destroy, :resend]
            before_action :set_invitation, only: [:destroy, :resend]

            request_params 'SellerInvitationCreateParams', action: :create do |body|
              body.attribute :email, :string, required: true, example: 'teammate@example.com'
            end

            # Pending only: an accepted invitation is a team member, which the
            # team endpoint lists.
            def index
              invitations = @seller.invitations.pending.order(created_at: :desc)

              render json: { data: invitations.map { |invitation| serialize(invitation) } }
            end

            # A seller the marketplace turned away has no team to join, the
            # same line the seller's own `invite` action draws.
            def create
              if @seller.rejected?
                return render_error(
                  code: ErrorHandler::ERROR_CODES[:processing_error],
                  message: I18n.t('spree.invitation_seller_rejected'),
                  status: :unprocessable_content
                )
              end

              invitation = @seller.invitations.new(
                email: params[:email],
                role: @seller.default_user_role,
                inviter: try_spree_current_user
              )

              if invitation.save
                render json: serialize(invitation), status: :created
              else
                render_validation_error(invitation.errors)
              end
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
                  message: I18n.t('spree.invitation_expired'),
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

            def authorize_seller_update
              authorize! :update, @seller
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
