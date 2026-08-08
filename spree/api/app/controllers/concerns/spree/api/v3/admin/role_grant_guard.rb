module Spree
  module Api
    module V3
      module Admin
        # Shared anti-amplification guards for everything that hands out
        # authority: role grants (admin_users#update, invitations#create),
        # role permission edits (roles#create/#update), and API-key minting.
        #
        # The common rule: a caller may only grant authority they effectively
        # hold, compared as expanded catalog keys. A JWT staffer's grant is the
        # union of their store-scoped roles' keys; a secret key's grant is its
        # scopes. Admin-role holders are unbounded; the literal `admin` role is
        # additionally grantable only by admins.
        module RoleGrantGuard
          extend ActiveSupport::Concern

          private

          # @param role_ids [Array<Integer,String>] resolved (decoded) role ids
          # @param require_role_management [Boolean] also require CanCanCan
          #   authority to create a RoleUser. Set by `admin_users#update`, whose
          #   own authorization is only `:update` on the user; the invitations
          #   flow leaves it off (its gate is `manage Invitation`).
          # @return [Boolean] true if the request was rejected (caller should return)
          def reject_unauthorized_role_grant!(role_ids, require_role_management: false)
            return false if role_ids.blank?

            # The management gate runs whenever a role mutation is attempted —
            # before resolving ids — so passing unknown ids can't slip the
            # reconciliation (which would still remove the user's current roles)
            # past a caller without role-management authority.
            return true if require_role_management && reject_without_role_management!

            roles = Spree::Role.where(id: role_ids.map(&:to_s)).to_a
            return false if roles.empty?

            return true if reject_admin_role_grant!(roles)
            return true if reject_privilege_escalating_grant!(roles)

            false
          end

          # Rejects granting permission keys beyond the caller's own — used by
          # roles#create/#update on the requested `permissions` array.
          #
          # @param keys [Array<String>]
          # @return [Boolean] true if the request was rejected
          def reject_unauthorized_permission_grant!(keys)
            excess = excess_permission_keys(keys)
            return false if excess.empty?

            deny_role_grant!(
              "You cannot grant permissions beyond your own: #{excess.join(', ')}",
              details: { excess_permissions: excess }
            )
          end

          # The requested keys (expanded) the caller does not hold. Empty when
          # the caller is unbounded.
          #
          # @param keys [Array<String>]
          # @return [Array<String>]
          def excess_permission_keys(keys)
            return [] if caller_holds_admin_role?

            Spree.permissions.expand_keys(keys) - caller_permission_keys
          end

          # For API-key principals CanCanCan is permissive (ScopedAuthorization is
          # their gate), so this only constrains JWT admins.
          def reject_without_role_management!
            return false if scope_limited_principal?
            return false if can?(:create, Spree::RoleUser)

            deny_role_grant!('You are not authorized to assign roles.')
          end

          def reject_admin_role_grant!(roles)
            return false unless roles.any? { |role| role.name == Spree::Role::ADMIN_ROLE }
            return false if caller_holds_admin_role?

            deny_role_grant!('You cannot grant the admin role.')
          end

          # A role is grantable when the caller holds every key it carries.
          def reject_privilege_escalating_grant!(roles)
            return false if caller_holds_admin_role?

            escalating = roles.reject { |role| excess_permission_keys(role.permissions).empty? }
            return false if escalating.empty?

            deny_role_grant!("You cannot grant roles beyond your own privileges: #{escalating.map(&:name).join(', ')}")
          end

          # The caller's effective grant as expanded catalog keys. A JWT
          # staffer contributes their store-scoped roles' keys; a secret-key
          # principal contributes its scopes (aliases expand against the
          # catalog).
          #
          # @return [Array<String>]
          def caller_permission_keys
            @caller_permission_keys ||=
              if scope_limited_principal?
                Spree.permissions.expand_keys(current_api_key.scopes)
              else
                Spree.permissions.expand_keys(caller_roles.flat_map(&:permissions))
              end
          end

          # The caller's store-admin roles, fetched once per request. Matched
          # on the store AND a store resource, mirroring
          # `Spree::Ability#staff_roles`: an assignment scoped to another
          # resource (a marketplace vendor) binds to that resource's store but
          # confers no store-admin authority, so it must not widen what the
          # caller may grant.
          #
          # @return [Array<Spree::Role>]
          def caller_roles
            return @caller_roles if defined?(@caller_roles)

            user = try_spree_current_user
            @caller_roles =
              if user.respond_to?(:role_users)
                user.role_users.
                  where(store: current_store, resource_type: Spree::Store.to_s).
                  includes(:role).map(&:role)
              else
                []
              end
          end

          def caller_holds_admin_role?
            return current_api_key.has_scope?('write_all') if scope_limited_principal?

            caller_roles.any? { |role| role.name == Spree::Role::ADMIN_ROLE } ||
              try_spree_current_user.try(:spree_admin?, current_store)
          end

          def deny_role_grant!(message, details: nil)
            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:access_denied],
              message: message,
              status: :forbidden,
              details: details
            )
            true
          end
        end
      end
    end
  end
end
