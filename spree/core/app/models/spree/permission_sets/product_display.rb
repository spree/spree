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
        can [:read, :admin], Spree::Property
        can [:read, :admin], Spree::ProductProperty
        can [:read, :admin], Spree::Metafield
        can [:read, :admin], Spree::Taxon
        can [:read, :admin], Spree::Taxonomy
        can [:read, :admin], Spree::Classification
        can [:read, :admin], Spree::Price
      end
    end
  end
end
