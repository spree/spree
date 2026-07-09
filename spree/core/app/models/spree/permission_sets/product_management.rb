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
        can :manage, Spree::Taxon
        can :manage, Spree::Taxonomy
        can :manage, Spree::Classification
        can :manage, Spree::Collection
        can :manage, Spree::ProductCollection
        can :manage, Spree::CollectionRule
        can :manage, Spree::Price
        can :manage, Spree::PriceList
        can :manage, Spree::PriceRule
        can :manage, Spree::Asset
        can :manage, Spree::ProductPublication
      end
    end
  end
end
