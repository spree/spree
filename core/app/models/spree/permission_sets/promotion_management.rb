# Permission set for managing promotions and discounts.
#
# This permission set provides access to create and manage promotions,
# coupon codes, and promotion rules.
#
# @example
#   Spree.permissions.assign(:marketing, Spree::PermissionSets::PromotionManagement)
#
module Spree
  module PermissionSets
    class PromotionManagement < Base
      def activate!
        can :manage, Spree::Promotion
        can :manage, Spree::PromotionRule
        can :manage, Spree::PromotionAction
        can :manage, Spree::PromotionCategory
        can :manage, Spree::CouponCode
        can [:read, :admin], Spree::Metafield
      end
    end
  end
end
