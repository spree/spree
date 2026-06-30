module Spree
  # Backwards-compatible shim for resources migrated from a many-to-many store
  # relationship to a single-store +belongs_to :store+ FK (Spree::Product in 5.5,
  # Spree::Promotion and Spree::PaymentMethod in 5.6). Maps the historic
  # +stores+/+store_ids+ accessors onto the singular +store+/+store_id+, warning
  # on use. The +spree_multi_store+ extension defines +SpreeMultiStore+ to
  # suppress the include and restore the real +has_many :stores+ association.
  module LegacyMultiStoreSupport
    extend ActiveSupport::Concern

    included do
      # Legacy accessors for the many-to-many store relationship. These are deprecated
      # and will be removed in Spree 6.0 once the models finish migrating to single-store ownership.
      # @return [ActiveRecord::Relation<Spree::Store>] the single store wrapped in a relation, or an empty relation if no store is set
      def stores
        Spree::Deprecation.warn(
          "#{self.class.base_class}#stores is deprecated. Please use #{self.class.base_class}#store instead. " \
          'If you want to continue using multiple stores please install spree_multi_store gem'
        )
        store ? Spree::Stores.where(id: store.id) : Spree::Store.none
      end

      def store_ids
        Spree::Deprecation.warn(
          "#{self.class.base_class}#store_ids is deprecated. Please use #{self.class.base_class}#store_id instead. " \
          'If you want to continue using multiple stores please install spree_multi_store gem'
        )
        store_id ? [store_id] : []
      end

      def stores=(stores)
        Spree::Deprecation.warn(
          "#{self.class.base_class}#stores= is deprecated. Please use #{self.class.base_class}#store= instead. " \
          'If you want to continue using multiple stores please install spree_multi_store gem'
        )
        self.store = Array(stores).compact.first
      end

      def store_ids=(store_ids)
        Spree::Deprecation.warn(
          "#{self.class.base_class}#store_ids= is deprecated. Please use #{self.class.base_class}#store_id= instead. " \
          'If you want to continue using multiple stores please install spree_multi_store gem'
        )
        self.store_id = Array(store_ids).compact_blank.first
      end
    end
  end
end
