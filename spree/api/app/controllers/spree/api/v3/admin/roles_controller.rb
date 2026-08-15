module Spree
  module Api
    module V3
      module Admin
        # Staff roles and their catalog permissions (docs/plans/6.0-admin-rbac.md).
        # Roles are global, not per-store — the controller ignores
        # `current_store` for that reason; assignments (RoleUser) are the
        # store-scoped half. Protection of the admin role and host-locked rows
        # lives on the model (`mutable` guards, `can_be_deleted?`).
        class RolesController < ResourceController
          include Spree::Api::V3::Admin::RoleGrantGuard

          scoped_resource :staff

          # POST /api/v3/admin/roles
          # A caller may only grant permissions they effectively hold — the
          # same anti-amplification rule as role grants and API-key minting.
          def create
            return if reject_unauthorized_permission_grant!(requested_permissions)

            super
          end

          # PATCH /api/v3/admin/roles/:id
          def update
            return if params.key?(:permissions) && reject_unauthorized_permission_grant!(requested_permissions)

            super
          end

          protected

          def model_class
            Spree::Role
          end

          def serializer_class
            Spree.api.admin_role_serializer
          end

          # The store's own roles. A role belonging to another resource — a
          # marketplace vendor's — is managed from that panel and never appears
          # in the staff role picker.
          def scope
            current_store.roles.accessible_by(current_ability, :show)
          end

          def collection_includes
            [:role_users]
          end

          # Roles created here belong to the store being administered — the
          # base builder stamps `store`, which a role does not have.
          def build_resource
            current_store.roles.build(permitted_params)
          end

          def permitted_params
            params.permit(:name, :description, permissions: [])
          end

          private

          def requested_permissions
            Array(params[:permissions]).map(&:to_s).reject(&:blank?)
          end
        end
      end
    end
  end
end
