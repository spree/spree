# CanCanCan ability for both halves of Spree authorization:
#
# - **Staff** (admin-user principals) are authorized through the permission
#   catalog: their store-scoped roles hold flat `read_<resource>` /
#   `write_<resource>` keys (see Spree::PermissionConfiguration and
#   docs/plans/6.0-admin-rbac.md), which compile to CanCanCan rules here. The
#   `admin` role grants everything.
# - **Customers and guests** get the fixed storefront baseline: read the
#   catalog, own their carts/orders/account. It is not configurable and is not
#   part of the permission catalog — customer authorization is ownership, not
#   RBAC.
#
# Host applications needing rules the catalog cannot express (record-level
# conditions, regional restrictions) register a plain CanCan::Ability class:
#
#   class RegionalSupportAbility
#     include CanCan::Ability
#
#     def initialize(user)
#       can :read, Spree::Order, market_id: user.market_id if user
#     end
#   end
#
#   Spree::Ability.register_ability(RegionalSupportAbility)
#
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
    #   (empty for storefront principals). Feeds `/me` and the admin key gate.
    attr_reader :permission_keys

    class << self
      # Registers an extra ability class merged into every Spree::Ability.
      #
      # @param ability_class [Class] a CanCan::Ability whose initializer takes
      #   the user
      def register_ability(ability_class)
        abilities.add(ability_class)
      end

      # @param ability_class [Class]
      def remove_ability(ability_class)
        abilities.delete(ability_class)
      end

      # @return [Set<Class>]
      def abilities
        @abilities ||= Set.new
      end
    end

    def initialize(user, options = {})
      alias_cancan_delete_action

      @user = user || Spree.customer_class.new
      @store = options[:store] || Spree::Current.store
      @permission_keys = []

      apply_storefront_permissions if storefront_principal?
      apply_staff_permissions if staff_principal?

      merge_registered_abilities
    end

    # Applies a single catalog key's grants and records it as activated.
    # Public so `register_ability` classes and host subclasses can grant
    # catalog capabilities in the same currency the key gate checks.
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

    # Customers and guests get the storefront baseline. When the host shares
    # one class between customers and admin users (the install generator does
    # this when only `user_class` is provided), a persisted user is both — the
    # baseline applies alongside staff role resolution.
    def storefront_principal?
      !staff_principal? || Spree.admin_user_class == Spree.customer_class
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

    # The user's roles on the current store.
    #
    # @return [Array<Spree::Role>]
    def staff_roles
      return [] unless @user.respond_to?(:role_users)

      @staff_roles ||= @user.role_users.where(store: @store).includes(:role).map(&:role)
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

    # --- storefront (customers and guests) ---

    # The fixed storefront baseline: browse the catalog, own your cart, order
    # and account. Ownership is expressed through hash conditions and cart
    # tokens; the Store API's scope-fetching remains the primary enforcement.
    def apply_storefront_permissions
      apply_storefront_catalog_permissions
      apply_storefront_purchase_permissions
      apply_storefront_account_permissions
    end

    def apply_storefront_catalog_permissions
      can :read, Spree::Collection
      can :read, Spree::Country
      can :read, Spree::OptionType
      can :read, Spree::OptionValue
      can :read, Spree::Product
      can :read, Spree::State
      can :read, Spree::Store
      can :read, Spree::Category
      can :read, Spree::Taxonomy
      can :read, Spree::Variant
      can :read, Spree::Zone
      can :read, Spree::Policy
    end

    def apply_storefront_purchase_permissions
      can :create, Spree::Order
      can :show, Spree::Order do |order, token|
        order.customer == user || order.token && token == order.token
      end
      can :update, Spree::Order do |order, token|
        !order.completed? && (order.customer == user || order.token && token == order.token)
      end

      can :create, Spree::Cart
      can :show, Spree::Cart do |cart, token|
        cart.customer == user || cart.token && token == cart.token
      end
      can [:update, :destroy], Spree::Cart do |cart, token|
        !cart.completed? && (cart.customer == user || cart.token && token == cart.token)
      end

      can :create, Spree::LineItem do |line_item, token|
        owner = line_item.owner
        owner.customer == user || owner.token && token == owner.token
      end
      can [:update, :destroy], Spree::LineItem do |line_item, token|
        owner = line_item.owner
        !owner.completed? && (owner.customer == user || owner.token && token == owner.token)
      end

      # Digital downloads - token-based access
      can :show, Spree::DigitalLink do |digital_link, token|
        digital_link.token == token
      end
    end

    def apply_storefront_account_permissions
      can :create, Spree.customer_class
      can [:show, :update, :destroy], Spree.customer_class, id: user.id

      can :manage, Spree::Address, user_id: user.id if user.persisted?
      can [:read, :destroy], Spree::CreditCard, user_id: user.id
      can :read, Spree::GiftCard, user_id: user.id
      can [:show, :destroy], Spree::NewsletterSubscriber, user_id: user.id

      can :manage, Spree::Wishlist, user_id: user.id
      can :show, Spree::Wishlist do |wishlist|
        wishlist.customer == user || wishlist.is_private == false
      end
      can [:create, :update, :destroy], Spree::WishedItem do |wished_item|
        wished_item.wishlist.customer == user
      end

      can :accept, Spree::Invitation,
          invitee_id: [user.id, nil], invitee_type: user.class.name, status: 'pending'
    end

    # --- extensions ---

    def merge_registered_abilities
      self.class.abilities.each do |ability_class|
        merge(ability_class.new(@user))
      end
    end
  end
end
