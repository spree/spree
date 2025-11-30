# Permission set for default storefront customers (both authenticated and guests).
#
# This permission set provides the standard permissions needed for browsing
# the store and making purchases.
#
# @example
#   Spree.permissions.assign(:default, Spree::PermissionSets::DefaultCustomer)
#
module Spree
  module PermissionSets
    class DefaultCustomer < Base
      def activate!
        # Read-only access to catalog
        can :read, Spree::Country
        can :read, Spree::OptionType
        can :read, Spree::OptionValue
        can :read, Spree::Product
        can :read, Spree::ProductProperty
        can :read, Spree::Property
        can :read, Spree::State
        can :read, Spree::Store
        can :read, Spree::Taxon
        can :read, Spree::Taxonomy
        can :read, Spree::Variant
        can :read, Spree::Zone

        # Content pages
        can :read, Spree::Policy
        can :read, Spree::Page
        can :read, Spree::Post
        can :read, Spree::PostCategory

        # Order management for the user's own orders
        can :create, Spree::Order
        can :show, Spree::Order do |order, token|
          order.user == user || order.token && token == order.token
        end
        can :update, Spree::Order do |order, token|
          !order.completed? && (order.user == user || order.token && token == order.token)
        end

        # User account management - available to all users (including guests for their own record)
        can :create, Spree.user_class
        can [:show, :update, :destroy], Spree.user_class, id: user.id

        # Address management
        can :manage, Spree::Address, user_id: user.id

        # Credit card management
        can [:read, :destroy], Spree::CreditCard, user_id: user.id

        # Wishlist management
        can :manage, Spree::Wishlist, user_id: user.id
        can :show, Spree::Wishlist do |wishlist|
          wishlist.user == user || wishlist.is_private == false
        end
        can [:create, :update, :destroy], Spree::WishedItem do |wished_item|
          wished_item.wishlist.user == user
        end

        # Invitation acceptance
        can :accept, Spree::Invitation, invitee_id: [user.id, nil], invitee_type: user.class.name, status: 'pending'
      end
    end
  end
end
