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
        can :read, Spree::Collection
        can :read, Spree::Country
        can :read, Spree::OptionType
        can :read, Spree::OptionValue
        can :read, Spree::Product
        can :read, Spree::State
        can :read, Spree::Store
        can :read, Spree::Category
        can :read, Spree::Variant
        can :read, Spree::Zone

        # Content pages
        can :read, Spree::Policy

        # Order management for the user's own orders
        can :create, Spree::Order
        can :show, Spree::Order do |order, token|
          order.customer == user || order.token && token == order.token
        end
        can :update, Spree::Order do |order, token|
          !order.completed? && (order.customer == user || order.token && token == order.token)
        end

        # Cart management — the checkout owner since the cart/order split
        can :create, Spree::Cart
        can :show, Spree::Cart do |cart, token|
          cart.customer == user || cart.token && token == cart.token
        end
        can [:update, :destroy], Spree::Cart do |cart, token|
          !cart.completed? && (cart.customer == user || cart.token && token == cart.token)
        end

        # Line item management
        can :create, Spree::LineItem do |line_item, token|
          owner = line_item.owner
          owner.customer == user || owner.token && token == owner.token
        end
        can [:update, :destroy], Spree::LineItem do |line_item, token|
          owner = line_item.owner
          !owner.completed? && (owner.customer == user || owner.token && token == owner.token)
        end

        # User account management - available to all users (including guests for their own record)
        can :create, Spree.customer_class
        can [:show, :update, :destroy], Spree.customer_class, id: user.id

        # Address management - only for persisted users with matching user_id
        can :manage, Spree::Address, user_id: user.id if user.persisted?

        # Credit card management
        can [:read, :destroy], Spree::CreditCard, user_id: user.id

        # Gift card management - users can view their own gift cards
        can :read, Spree::GiftCard, user_id: user.id

        # Newsletter subscription management — customers manage their own newsletter subscribers
        can [:show, :destroy], Spree::NewsletterSubscriber, user_id: user.id

        # Wishlist management
        can :manage, Spree::Wishlist, user_id: user.id
        can :show, Spree::Wishlist do |wishlist|
          wishlist.customer == user || wishlist.is_private == false
        end
        can [:create, :update, :destroy], Spree::WishedItem do |wished_item|
          wished_item.wishlist.customer == user
        end

        # Invitation acceptance
        can :accept, Spree::Invitation, invitee_id: [user.id, nil], invitee_type: user.class.name, status: 'pending'

        # Digital downloads - token-based access
        can :show, Spree::DigitalLink do |digital_link, token|
          digital_link.token == token
        end
      end
    end
  end
end
