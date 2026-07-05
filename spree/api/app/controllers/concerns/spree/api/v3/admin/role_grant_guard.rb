module Spree
  module Api
    module V3
      module Admin
        # Shared guard for staff role grants (admin_users#update and
        # invitations#create). A grant is rejected when, in order:
        #
        #   1. (opt-in) the caller can't `:create` a Spree::RoleUser — i.e. lacks
        #      the RoleManagement permission set;
        #   2. it includes the literal `admin` role and the caller does not hold
        #      it on the current store;
        #   3. it includes any role whose permission sets exceed the caller's own
        #      (catches SuperUser-equivalent custom roles the name check misses).
        #
        # API-key principals hold no roles, so they can grant only roles that
        # activate no permission sets.
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

          # A caller holding the admin role bounds nothing; the literal admin role
          # is already gated by reject_admin_role_grant!.
          def reject_privilege_escalating_grant!(roles)
            return false if caller_holds_admin_role?

            caller_sets = Spree.permissions.permission_sets_for_roles(caller_role_names)
            escalating = roles.reject { |role| grantable_within?(role, caller_sets) }
            return false if escalating.empty?

            deny_role_grant!("You cannot grant roles beyond your own privileges: #{escalating.map(&:name).join(', ')}")
          end

          # A role is grantable when every permission set it activates is one the
          # caller already holds.
          def grantable_within?(role, caller_sets)
            (Spree.permissions.permission_sets_for(role.name) - caller_sets).empty?
          end

          # The caller's store-scoped role names, fetched once per request.
          # Scoped by store_id so the caller's own privileges are recognized even
          # when their role is held on a non-store resource bound to this store.
          def caller_role_names
            return @caller_role_names if defined?(@caller_role_names)

            user = try_spree_current_user
            @caller_role_names =
              if user.respond_to?(:role_users)
                user.role_users.where(store: current_store).joins(:role).
                  pluck("#{Spree::Role.table_name}.name")
              else
                []
              end
          end

          def caller_holds_admin_role?
            caller_role_names.include?(Spree::Role::ADMIN_ROLE)
          end

          def deny_role_grant!(message)
            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:access_denied],
              message: message,
              status: :forbidden
            )
            true
          end
        end
      end
    end
  end
end
