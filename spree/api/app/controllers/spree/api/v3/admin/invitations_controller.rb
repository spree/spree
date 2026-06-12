module Spree
  module Api
    module V3
      module Admin
        # Manages staff invitations for the current store. Each invitation
        # carries an email + role; on accept, a `Spree::RoleUser` is created
        # via the invitation's `after_accept` callback and the invitee
        # becomes a member of the staff list for this store.
        class InvitationsController < ResourceController
          include Spree::Api::V3::Admin::RoleGrantGuard

          scoped_resource :settings

          # POST /api/v3/admin/invitations
          # Guards against inviting a new staff member straight into the admin
          # super-role unless the inviter already holds it.
          def create
            return if reject_unauthorized_role_grant!(Array(permitted_params[:role_id]))

            super
          end

          # PATCH /api/v3/admin/invitations/:id/resend
          # Issues a fresh token + email for an existing pending invitation.
          # The model's `resend!` is responsible for resetting `expires_at`
          # and dispatching the mailer.
          def resend
            @resource = find_resource
            authorize!(:update, @resource)

            @resource.resend!
            render json: serialize_resource(@resource)
          end

          # Invitations are immutable post-create — UI calls `resend` for
          # token rotation, `destroy` to revoke. Clearing the action set
          # keeps the surface honest if a client ever fires PATCH directly.
          def update
            head :method_not_allowed
          end

          protected

          def model_class
            Spree::Invitation
          end

          def serializer_class
            Spree.api.admin_invitation_serializer
          end

          def collection_includes
            [:role, :inviter]
          end

          def scope
            Spree::Invitation.
              where(resource: current_store).
              accessible_by(current_ability, :show)
          end

          def build_resource
            scope.new(permitted_params).tap do |invitation|
              invitation.resource = current_store
              invitation.inviter = try_spree_current_user
            end
          end

          # `email` and `role_id` are flat — `role_id` accepts a prefixed ID.
          def permitted_params
            attrs = params.permit(:email, :role_id)
            if attrs[:role_id].present? && Spree::PrefixedId.prefixed_id?(attrs[:role_id])
              attrs[:role_id] = Spree::PrefixedId.decode_prefixed_id(attrs[:role_id])
            end
            attrs
          end
        end
      end
    end
  end
end
