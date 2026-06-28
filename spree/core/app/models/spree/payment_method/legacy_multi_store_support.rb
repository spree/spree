module Spree
  class PaymentMethod
    # Legacy multi-store support. In Spree 5.6+ a payment method
    # +belongs_to :store+ (single owner), so this module only provides a
    # fallback for legacy code that still references
    # +Spree::PaymentMethod#stores+. The +spree_multi_store+ extension defines
    # +SpreeMultiStore+, which suppresses this module and restores the real
    # +has_many :stores+ association.
    module LegacyMultiStoreSupport
      extend ActiveSupport::Concern

      included do
        def stores
          Spree::Deprecation.warn(
            "Spree::PaymentMethod#stores is deprecated. Please use Spree::PaymentMethod#store instead. If you want to continue using multiple stores please install spree_multi_store gem"
          )
          store ? [store] : []
        end

        def store_ids
          Spree::Deprecation.warn(
            "Spree::PaymentMethod#store_ids is deprecated. Please use Spree::PaymentMethod#store_id instead. If you want to continue using multiple stores please install spree_multi_store gem"
          )
          store_id ? [store_id] : []
        end

        def stores=(stores)
          Spree::Deprecation.warn(
            "Spree::PaymentMethod#stores= is deprecated. Please use Spree::PaymentMethod#store= instead. If you want to continue using multiple stores please install spree_multi_store gem"
          )
          self.store = Array(stores).compact.first
        end

        def store_ids=(store_ids)
          Spree::Deprecation.warn(
            "Spree::PaymentMethod#store_ids= is deprecated. Please use Spree::PaymentMethod#store_id= instead. If you want to continue using multiple stores please install spree_multi_store gem"
          )
          self.store_id = Array(store_ids).compact_blank.first
        end
      end
    end
  end
end
