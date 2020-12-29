# Implementation class for Cancan gem.  Instead of overriding this class, consider adding new permissions
# using the special +register_ability+ method which allows extensions to add their own abilities.
#
# See http://github.com/ryanb/cancan for more details on cancan.
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

    def initialize(user)
      # add cancancan aliasing
      alias_action :delete, to: :destroy
      alias_action :create, :update, :destroy, to: :modify

      user ||= Spree.user_class.new

      if user.respond_to?(:has_spree_role?) && user.has_spree_role?('admin')
        can :manage, :all
      else
        can :read, Country
        can :read, OptionType
        can :read, OptionValue
        can :create, Order
        can :show, Order do |order, token|
          order.user == user || order.token && token == order.token
        end
        can :update, Order do |order, token|
          !order.completed? && (order.user == user || order.token && token == order.token)
        end
        can :manage, Spree::Address do |address|
          address.user == user
        end
        can :create, Spree::Address do |_address|
          user.id.present?
        end
        can :read, CreditCard, user_id: user.id
        can :read, Product
        can :read, ProductProperty
        can :read, Property
        can :create, Spree.user_class
        can [:show, :update, :destroy], Spree.user_class, id: user.id
        can :read, State
        can :read, Taxon
        can :read, Taxonomy
        can :read, Variant
        can :read, Zone
      end

      # Include any abilities registered by extensions, etc.
      Ability.abilities.merge(abilities_to_register).each do |clazz|
        merge clazz.new(user)
      end

      # Protect admin role
      cannot [:update, :destroy], Role, name: ['admin']
    end

    private

    # you can override this method to register your abilities
    # this method has to return array of classes
    def abilities_to_register
      []
    end
  end
end
