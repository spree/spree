# Permission set for full product and catalog management.
#
# This permission set provides complete access to manage products, variants,
# and related catalog models like taxonomies and properties.
#
# @example
#   Spree.permissions.assign(:merchandiser, Spree::PermissionSets::ProductManagement)
#
module Spree
  module PermissionSets
    class ProductManagement < Base
      def activate!
        can :manage, Spree::Product
        can :manage, Spree::Variant
        can :manage, Spree::OptionType
        can :manage, Spree::OptionValue
        can :manage, Spree::Property
        can :manage, Spree::ProductProperty
        can :manage, Spree::Taxon
        can :manage, Spree::Taxonomy
        can :manage, Spree::Classification
        can :manage, Spree::Price
        can :manage, Spree::Asset
      end
    end
  end
end
