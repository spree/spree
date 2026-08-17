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

    # @return [Object] the resource whose role assignments this ability reads —
    #   the store for the admin panel, a Spree::Seller for a seller panel
    attr_reader :resource

    # @return [Array<String>] the expanded catalog keys this ability activated
    #   (empty for non-staff principals). Feeds `/me` and the admin key gate.
    attr_reader :permission_keys

    # @param user [Object] the principal
    # @param options [Hash]
    # @option options [Spree::Store] :store the current store
    # @option options [Object] :resource the resource whose assignments grant
    #   capability — defaults to the store. Pass a Spree::Seller to build the
    #   ability of a seller panel from that seller's own role assignments.
    #
    #   **The ability answers capability, never tenancy.** A seller holding
    #   `write_orders` gets `can :manage, Spree::Order` — the model class, not
    #   that seller's subset — exactly as a store admin does. Which records a
    #   panel may touch is decided by scope-fetching in the controller
    #   (`current_seller.orders`), the same way store isolation works on the
    #   admin branch. A panel controller that authorizes with `accessible_by`
    #   or `authorize!` and does NOT scope-fetch is reading store-wide.
    def initialize(user, options = {})
      alias_cancan_delete_action

      @user = user || Spree.customer_class.new
      @store = options[:store] || Spree::Current.store
      @resource = options[:resource] || @store
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

      if full_access?(roles)
        activate_full_access
      else
        apply_staff_baseline
        grantable_keys_for(roles).each { |key| activate_permission(key) }
      end
    end

    # Every key the roles ask for, bounded at activation by what each role's
    # audience may hold. `Spree::Role` validates the same bound on write, but a
    # catalog that changes after the role was saved would leave stale keys
    # behind — the write-time check is a UX affordance, this is the boundary.
    #
    # @param roles [Array<Spree::Role>]
    # @return [Array<String>]
    def grantable_keys_for(roles)
      roles.flat_map do |role|
        keys = Spree.permissions.expand_keys(role.permissions)
        next keys if role.staff?

        keys & Spree.permissions.grantable_keys(role.audience)
      end.uniq
    end

    # The super-role and the implicit-admin fallback are store-panel concepts:
    # `admin` means "everything in this store", which is not a grant another
    # panel's roles can carry. Outside the store panel, capability only ever
    # comes from catalog keys.
    def full_access?(roles)
      return false unless store_resource?

      roles.any?(&:admin?) || implicit_admin?(roles)
    end

    # @return [Boolean] whether this ability is being built for the store's own
    #   back office, as opposed to another panel (a marketplace seller's)
    def store_resource?
      @resource.is_a?(Spree::Store)
    end

    # The user's roles on the ability's resource.
    #
    # A role names what it governs, so matching on it answers both questions at
    # once: which panel these grants belong to, and which tenant. A role owned
    # by a marketplace seller cannot be picked up here however it was assigned.
    #
    # @return [Array<Spree::Role>]
    def staff_roles
      return @staff_roles if defined?(@staff_roles)

      @staff_roles =
        if @user.respond_to?(:spree_roles) && @resource.present?
          @user.spree_roles.for_resource(@resource).to_a
        else
          []
        end
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
    #
    # The store grant is unrestricted only for the store's own back office.
    # Another panel reads the one store it operates under and no other, so a
    # marketplace's sellers cannot enumerate its sibling stores.
    def apply_staff_baseline
      can :read, Spree::Country
      can :read, Spree::State

      if store_resource? || @store.nil?
        can :read, Spree::Store
      else
        can :read, Spree::Store, id: @store.id
      end
    end

  end
end
