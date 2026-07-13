# Permission set for viewing products and catalog information.
#
# This permission set provides read-only access to products, variants,
# and related catalog models.
#
# @example
#   Spree.permissions.assign(:content_editor, Spree::PermissionSets::ProductDisplay)
#
module Spree
  module PermissionSets
    class ProductDisplay < Base
      def activate!
        can [:read, :admin, :index], Spree::Product
        can [:read, :admin], Spree::Variant
        can [:read, :admin], Spree::OptionType
        can [:read, :admin], Spree::OptionValue
        can [:read, :admin], Spree::Metafield
        can [:read, :admin], Spree::Collection
        can [:read, :admin], Spree::Category
        can [:read, :admin], Spree::Taxonomy
        can [:read, :admin], Spree::ProductCategory
        can [:read, :admin], Spree::Price
        can [:read, :admin], Spree::PriceList
        can [:read, :admin], Spree::PriceRule
      end
    end
  end
end
