module Spree
  module Api
    module V3
      module Admin
        # Manages staff for the current store. "Staff" = admin users with at
        # least one `Spree::RoleUser` whose `resource` is the current store.
        # The legacy controller hard-deletes the global account on destroy;
        # this v3 endpoint instead removes the per-store `RoleUser` rows so
        # the user keeps their account (and access to other stores).
        class AdminUsersController < ResourceController
          include Spree::Api::V3::Admin::RoleGrantGuard

          scoped_resource :settings

          # POST is not exposed — staff are created via invitations.
          def create
            head :method_not_allowed
          end

          # DELETE /api/v3/admin/admin_users/:id
          # Removes role assignments for the current store rather than deleting
          # the account globally. The user keeps access to any other stores.
          def destroy
            authorize!(:destroy, @resource)
            @resource.role_users.where(resource: current_store).destroy_all
            head :no_content
          end

          # PATCH allows updating identity fields and replacing the user's
          # roles for this store. `role_ids` accepts prefixed IDs and is
          # applied via `add_role`/`remove_role` so the change is scoped to
          # `current_store` and never touches other-store assignments.
          def update
            authorize!(:update, @resource)

            # `nil` when the key is absent (leave roles untouched); an array
            # (possibly empty, to clear) when the client sends `role_ids`.
            role_ids = role_ids_param if params.key?(:role_ids)
            return if role_ids && reject_unauthorized_role_grant!(role_ids)

            if @resource.update(identity_params)
              apply_role_ids(role_ids) if role_ids
              render json: serialize_resource(@resource)
            else
              render_validation_error(@resource.errors)
            end
          end

          protected

          def model_class
            Spree.admin_user_class
          end

          def serializer_class
            Spree.api.admin_admin_user_serializer
          end

          def collection_includes
            [{ role_users: :role }]
          end

          # Restrict to users with a role assignment on the current store.
          # `accessible_by` enforces CanCanCan on top.
          def scope
            model_class.
              joins(:role_users).
              where(spree_role_users: { resource: current_store }).
              distinct.
              accessible_by(current_ability, :show)
          end

          private

          def identity_params
            params.permit(:first_name, :last_name)
          end

          def role_ids_param
            ids = Array(params[:role_ids])
            ids.map { |id| Spree::PrefixedId.prefixed_id?(id) ? Spree::PrefixedId.decode_prefixed_id(id) : id }.compact
          end

          # Reconcile the user's roles on this store to match `desired_role_ids`.
          # Adds missing assignments and removes extras — no-op for unchanged.
          def apply_role_ids(desired_role_ids)
            current = @resource.role_users.where(resource: current_store).pluck(:role_id).map(&:to_s)
            target = desired_role_ids.map(&:to_s)

            (target - current).each do |role_id|
              role = Spree::Role.find_by(id: role_id)
              @resource.role_users.find_or_create_by!(role: role, resource: current_store) if role
            end

            (current - target).each do |role_id|
              @resource.role_users.where(role_id: role_id, resource: current_store).destroy_all
            end
          end
        end
      end
    end
  end
end
