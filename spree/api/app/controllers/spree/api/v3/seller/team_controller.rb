module Spree
  module Api
    module V3
      module Seller
        # The people who run this seller.
        #
        # Rooted at `current_seller` throughout, so a seller can only ever see
        # and change their own team. Inviting reuses the workflow the operator
        # calls, which means one invitation rail and one set of hooks.
        #
        # No custom roles: every member holds the seller's own seeded admin
        # role, which already carries the whole seller vocabulary. Splitting
        # that into narrower roles is a design of its own.
        class TeamController < Seller::BaseController
          scoped_resource :seller_profile

          before_action :set_member, only: [:destroy]

          def index
            render json: { data: members.map { |member| serialize_member(member) } }
          end

          # Invites a colleague onto this seller's team. They join when they
          # accept, on the same invitation rail — and same email — the
          # marketplace operator's invitations use.
          #
          # Not `Spree::Sellers::Invite`: that workflow means "open this seller
          # for its first owner" and moves the seller to `invited`. A trading
          # seller's status must not flip because someone hired staff, and the
          # workflow rightly refuses an approved seller. Hiring is not a
          # lifecycle transition.
          def create
            invitation = current_seller.invitations.new(
              email: params[:email],
              role: current_seller.default_user_role,
              inviter: try_spree_current_user
            )

            if invitation.save
              render json: serialize_invitation(invitation), status: :created
            else
              render_validation_error(invitation.errors)
            end
          end

          # Revokes a member's access. The seller keeps at least one member:
          # emptying the team would leave a seller nobody can sign in to, and
          # only the operator could put someone back.
          #
          # Counted and removed under a lock on the seller. Unlocked, two
          # concurrent deletes against a two-member team both see two and both
          # proceed — the one state this endpoint exists to prevent, and one a
          # seller cannot repair themselves.
          def destroy
            removed = current_seller.with_lock do
              # `distinct`: `users` reaches through role_users, so a member
              # holding two roles on this seller is counted twice — while
              # `remove_user` deletes every one of their roles at once. Without
              # it, a two-role seller with one person reads as a team of two
              # and this check would let them remove themselves.
              next false if current_seller.users.distinct.count <= 1

              current_seller.remove_user(@member)
              true
            end

            return head :no_content if removed

            render_error(
              code: ErrorHandler::ERROR_CODES[:processing_error],
              message: Spree.t(:seller_team_last_member),
              status: :unprocessable_content
            )
          end

          protected

          def read_actions
            %w[index]
          end

          private

          def members
            @members ||= current_seller.users.to_a
          end

          def set_member
            @member = current_seller.users.find_by_prefix_id!(params[:id])
          end

          def serialize_member(member)
            Spree.api.seller_team_member_serializer.new(member, params: { store: current_store }).to_h
          end

          def serialize_invitation(invitation)
            Spree.api.seller_invitation_serializer.new(invitation, params: { store: current_store }).to_h
          end
        end
      end
    end
  end
end
