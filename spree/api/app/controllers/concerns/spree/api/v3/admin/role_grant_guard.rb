module Spree
  module Api
    module V3
      module Admin
        # Shared guard preventing role-assignment privilege escalation. Staff
        # role grants (via admin_users#update and invitations#create) must not
        # let a caller hand out the `admin` super-role unless they already hold
        # it on the current store. API-key principals have no human identity to
        # bound the grant, so they can never grant the admin role.
        #
        # Without this, any principal able to write staff (`write_settings`
        # scope, or a `UserManagement`/`RoleManagement` JWT role) could promote
        # an account to store super-admin. See the 2026-06 admin API security
        # review (Vulns 2-4).
        module RoleGrantGuard
          extend ActiveSupport::Concern

          private

          # @param role_ids [Array<Integer,String>] resolved (decoded) role ids
          # @return [Boolean] true if the request was rejected (caller should return)
          def reject_unauthorized_role_grant!(role_ids)
            return false if role_ids.blank?

            admin_role_id = Spree::Role.admin.pick(:id)
            return false if admin_role_id.blank?
            return false unless role_ids.map(&:to_s).include?(admin_role_id.to_s)
            return false if caller_holds_admin_role?

            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:access_denied],
              message: 'You cannot grant the admin role.',
              status: :forbidden
            )
            true
          end

          # Mirrors how Spree::Ability activates the super-user permission set:
          # admin-ness is decided by `spree_roles` membership (resource-agnostic),
          # not by a per-store RoleUser. API-key principals have no user and so
          # never count as holding the admin role.
          def caller_holds_admin_role?
            user = try_spree_current_user
            return false unless user.respond_to?(:spree_roles)

            user.spree_roles.exists?(name: Spree::Role::ADMIN_ROLE)
          end
        end
      end
    end
  end
end
