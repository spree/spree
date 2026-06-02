module Spree
  class Product
    # Legacy multi-store support. In Spree 5.5+ the +Spree::ProductPublication+ model
    # handles the Product↔Store relation, so this module only provides a fallback
    # for legacy code that still references +Spree::Product#stores+.
    module LegacyMultiStoreSupport
      extend ActiveSupport::Concern

      included do
        def stores
          Spree::Deprecation.warn(
            "Spree::Product#stores is deprecated. Please use Spree::Product.store instead. If you want to continue using multiple stores please install spree_multi_store gem"
          )
          store ? [store] : []
        end

        def store_ids
          Spree::Deprecation.warn(
            "Spree::Product#store_ids is deprecated. Please use Spree::Product.store_id instead. If you want to continue using multiple stores please install spree_multi_store gem"
          )
          store_id ? [store_id] : []
        end

        def stores=(stores)
          Spree::Deprecation.warn(
            "Spree::Product#stores= is deprecated. Please use Spree::Product.store= instead. If you want to continue using multiple stores please install spree_multi_store gem"
          )
          self.store = Array(stores).compact.first
        end

        def store_ids=(store_ids)
          Spree::Deprecation.warn(
            "Spree::Product#store_ids= is deprecated. Please use Spree::Product.store_id= instead. If you want to continue using multiple stores please install spree_multi_store gem"
          )
          self.store_id = Array(store_ids).compact_blank.first
        end
      end
    end
  end
end
