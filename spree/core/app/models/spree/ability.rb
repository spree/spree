# CanCanCan ability for staff (back-office) authorization only: admin-user
# principals are authorized through the permission catalog — their
# store-scoped roles hold flat `read_<resource>` / `write_<resource>` keys
# (see Spree::PermissionConfiguration and docs/plans/6.0-admin-rbac.md),
# which compile to CanCanCan rules here. The `admin` role grants everything.
#
# Customers and guests never touch CanCanCan: the Store API authorizes by
# ownership-scoped queries plus Spree::Storefront::AccessPolicy (carried by
# `Spree::Dependencies.storefront_access_policy_class`). An ability built for
# a customer principal simply has no rules.
#
# Replace the whole class via `Spree::Dependencies.ability_class` when an
# application needs rules the catalog cannot express.
require 'cancan'

module Spree
  class Ability
    include CanCan::Ability

    # @return [Object] the current user (a customer, an admin user, or a new
    #   customer instance for guests)
    attr_reader :user

    # @return [Spree::Store, nil] the current store
    attr_reader :store

    # @return [Array<String>] the expanded catalog keys this ability activated
    #   (empty for non-staff principals). Feeds `/me` and the admin key gate.
    attr_reader :permission_keys

    def initialize(user, options = {})
      alias_cancan_delete_action

      @user = user || Spree.customer_class.new
      @store = options[:store] || Spree::Current.store
      @permission_keys = []

      apply_staff_permissions if staff_principal?
    end

    # Applies a single catalog key's grants and records it as activated.
    # Public so host subclasses can grant catalog capabilities in the same
    # currency the key gate checks.
    #
    # @param key [String, Symbol] a catalog key (`'write_orders'`)
    # @return [Boolean] whether the key resolved
    def activate_permission(key)
      return false unless Spree.permissions.activate_key(self, key)

      @permission_keys |= Spree.permissions.expand_keys([key])
      true
    end

    protected

    def alias_cancan_delete_action
      alias_action :delete, to: :destroy
      alias_action :create, :update, :destroy, to: :modify
    end

    # Staff = a persisted admin-user principal. Customers never resolve roles
    # (storefront authorization is ownership, not RBAC), which also spares a
    # role_users query on every storefront request.
    def staff_principal?
      @user.persisted? && @user.is_a?(Spree.admin_user_class)
    end

    # --- staff ---

    def apply_staff_permissions
      roles = staff_roles

      if roles.any? { |role| role.name == Spree::Role::ADMIN_ROLE } || implicit_admin?(roles)
        activate_full_access
      else
        apply_staff_baseline
        Spree.permissions.expand_keys(roles.flat_map(&:permissions)).each do |key|
          activate_permission(key)
        end
      end
    end

    # The user's store-admin roles on the current store.
    #
    # Assignments are matched on the store AND on a store resource: a
    # `RoleUser` scoped to a non-store resource (a marketplace vendor, say)
    # binds to that resource's store, so matching on `store_id` alone would
    # let a vendor's own staff role grant store-wide admin capability. Those
    # assignments belong to their own panel's ability, not this one.
    #
    # @return [Array<Spree::Role>]
    def staff_roles
      return [] unless @user.respond_to?(:role_users)

      @staff_roles ||= @user.role_users.
                       where(store: @store, resource_type: Spree::Store.to_s).
                       includes(:role).map(&:role)
    end

    # Backward-compatible fallback for principals with no role rows whose
    # admin status is determined differently (e.g. mocked in specs).
    def implicit_admin?(roles)
      roles.empty? && @user.try(:spree_admin?, @store)
    end

    # Full access. Record-state safety (order cancel/destroy eligibility, the
    # admin role's immutability) is enforced by model and workflow guards, not
    # ability rules — see the Axis A/B split in docs/plans/decisions.md.
    def activate_full_access
      can :manage, :all
      @permission_keys = Spree.permissions.catalog_keys
    end

    # Reference data every staff member can read regardless of keys — address
    # forms need countries/states, and the dashboard shell reads the store.
    def apply_staff_baseline
      can :read, Spree::Country
      can :read, Spree::State
      can :read, Spree::Store
    end

  end
end
