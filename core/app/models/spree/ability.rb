# Implementation class for Cancan gem. Instead of overriding this class, consider adding new permissions
# using the special +register_ability+ method which allows extensions to add their own abilities.
#
# The preferred way to add permissions is now through permission sets. See Spree::PermissionSets::Base
# for more details on creating custom permission sets.
#
# @example Configuring role permissions
#   Spree.permissions.assign(:customer_service, [
#     Spree::PermissionSets::OrderDisplay,
#     Spree::PermissionSets::UserManagement
#   ])
#
# See https://github.com/CanCanCommunity/cancancan for more details.
require 'cancan'

module Spree
  class Ability
    include CanCan::Ability

    class_attribute :abilities
    self.abilities = Set.new

    # @return [Object] the current user
    attr_reader :user

    # @return [Spree::Store, nil] the current store
    attr_reader :store

    # Allows us to go beyond the standard cancan initialize method which makes it difficult for engines to
    # modify the default +Ability+ of an application.  The +ability+ argument must be a class that includes
    # the +CanCan::Ability+ module.  The registered ability should behave properly as a stand-alone class
    # and therefore should be easy to test in isolation.
    def self.register_ability(ability)
      abilities.add(ability)
    end

    def self.remove_ability(ability)
      abilities.delete(ability)
    end

    def initialize(user, options = {})
      alias_cancan_delete_action

      @user = user || Spree.user_class.new
      @store = options[:store] || Spree::Current.store

      apply_permissions_from_sets

      # Include any abilities registered by extensions, etc.
      # this is legacy behaviour and should be removed in Spree 5.0
      Ability.abilities.merge(abilities_to_register).each do |clazz|
        merge clazz.new(@user)
      end
    end

    protected

    # you can override this method to register your abilities
    # this method has to return array of classes
    def abilities_to_register
      []
    end

    def alias_cancan_delete_action
      alias_action :delete, to: :destroy
      alias_action :create, :update, :destroy, to: :modify
    end

    # Applies permissions based on the user's roles and the configured permission sets.
    def apply_permissions_from_sets
      role_names = determine_role_names
      permission_sets = Spree.permissions.permission_sets_for_roles(role_names)

      # If no permission sets are configured for the user's roles, use legacy behavior
      if permission_sets.empty?
        apply_legacy_permissions
      else
        activate_permission_sets(permission_sets)
      end
    end

    # Determines the role names for the current user.
    #
    # @return [Array<Symbol>] the role names
    def determine_role_names
      return [:default] unless @user.persisted?

      # First, try to get roles from the spree_roles association
      if @user.respond_to?(:spree_roles)
        role_names = @user.spree_roles.pluck(:name).map(&:to_sym)
        return role_names if role_names.any?
      end

      # Fall back to checking spree_admin? for backward compatibility
      # This supports cases where roles are mocked or admin status is determined differently
      if @user.try(:spree_admin?, @store)
        [:admin]
      else
        [:default]
      end
    end

    # Activates the given permission sets.
    #
    # @param permission_sets [Array<Class>] the permission set classes to activate
    def activate_permission_sets(permission_sets)
      permission_sets.each do |permission_set_class|
        permission_set = permission_set_class.new(self)
        permission_set.activate!
      end
    end

    # Legacy permission application for backward compatibility.
    # This is used when no permission sets are configured for the user's roles.
    def apply_legacy_permissions
      if @user.persisted? && @user.is_a?(Spree.admin_user_class) && @user.try(:spree_admin?, @store)
        apply_admin_permissions(@user, { store: @store })
      else
        apply_user_permissions(@user, { store: @store })
      end

      protect_admin_role
    end

    def apply_admin_permissions(_user, _options)
      can :manage, :all
      cannot :cancel, Spree::Order
      can :cancel, Spree::Order, &:allow_cancel?
      cannot :destroy, Spree::Order
      can :destroy, Spree::Order, &:can_be_deleted?
      cannot [:edit, :update], Spree::RefundReason, mutable: false
      cannot [:edit, :update], Spree::ReimbursementType, mutable: false
    end

    def apply_user_permissions(user, _options)
      can :read, ::Spree::Country
      can :read, ::Spree::OptionType
      can :read, ::Spree::OptionValue
      can :create, ::Spree::Order
      can :show, ::Spree::Order do |order, token|
        order.user == user || order.token && token == order.token
      end
      can :update, ::Spree::Order do |order, token|
        !order.completed? && (order.user == user || order.token && token == order.token)
      end
      can :manage, ::Spree::Address, user_id: user.id
      can [:read, :destroy], ::Spree::CreditCard, user_id: user.id
      can :read, ::Spree::Product
      can :read, ::Spree::ProductProperty
      can :read, ::Spree::Property
      can :create, ::Spree.user_class
      can [:show, :update, :destroy], ::Spree.user_class, id: user.id
      can :read, ::Spree::State
      can :read, ::Spree::Store
      can :read, ::Spree::Taxon
      can :read, ::Spree::Taxonomy
      can :read, ::Spree::Variant
      can :read, ::Spree::Zone
      can :manage, ::Spree::Wishlist, user_id: user.id
      can :show, ::Spree::Wishlist do |wishlist|
        wishlist.user == user || wishlist.is_private == false
      end
      can [:create, :update, :destroy], ::Spree::WishedItem do |wished_item|
        wished_item.wishlist.user == user
      end
      can :accept, Spree::Invitation, invitee_id: [user.id, nil], invitee_type: user.class.name, status: 'pending'
      can :read, ::Spree::Policy
      can :read, ::Spree::Page
      can :read, ::Spree::Post
      can :read, ::Spree::PostCategory
    end

    def protect_admin_role
      cannot [:update, :destroy], ::Spree::Role, name: ['admin']
    end
  end
end
