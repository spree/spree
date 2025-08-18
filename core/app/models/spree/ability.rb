# Implementation class for Cancan gem. Instead of overriding this class, consider adding new permissions
# using the special +register_ability+ method which allows extensions to add their own abilities.
#
# See https://github.com/CanCanCommunity/cancancan for more details.
require 'cancan'

module Spree
  class Ability
    include CanCan::Ability

    class_attribute :abilities
    self.abilities = Set.new

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

      user ||= Spree.user_class.new
      store ||= options[:store] || Spree::Current.store

      if user.persisted? && user.is_a?(Spree.admin_user_class) && user.try(:spree_admin?, store)
        apply_admin_permissions(user, options)
      else
        apply_user_permissions(user, options)
      end

      # Include any abilities registered by extensions, etc.
      # this is legacy behaviour and should be removed in Spree 5.0
      Ability.abilities.merge(abilities_to_register).each do |clazz|
        merge clazz.new(user)
      end

      protect_admin_role
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
    end

    def protect_admin_role
      cannot [:update, :destroy], ::Spree::Role, name: ['admin']
    end
  end
end
