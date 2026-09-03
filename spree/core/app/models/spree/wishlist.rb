module Spree
  class Wishlist < Spree.base_class
    has_prefix_id :wl  # Spree-specific: wishlist

    include Spree::SingleStoreResource

    publishes_lifecycle_events

    if Rails::VERSION::STRING >= '7.1.0'
      has_secure_token on: :save
    else
      has_secure_token
    end

    belongs_to :customer, class_name: "::#{Spree.customer_class}", touch: true
    include Spree::DeprecatedCustomerAlias
    belongs_to :store, class_name: 'Spree::Store'

    has_many :wishlist_items, class_name: 'Spree::WishlistItem', dependent: :destroy
    has_many :wished_items, class_name: 'Spree::WishlistItem', inverse_of: :wishlist, deprecated: true
    has_many :variants, through: :wishlist_items, source: :variant, class_name: 'Spree::Variant'
    has_many :products, -> { distinct }, through: :variants, source: :product, class_name: 'Spree::Product'

    after_commit :ensure_default_exists_and_is_unique
    validates :name, presence: true

    def include?(variant_id)
      wishlist_items.exists?(variant_id: variant_id)
    end

    # returns the number of items in the wishlist
    #
    # @return [Integer]
    def wishlist_items_count
      @wishlist_items_count ||= variant_ids.count
    end

    # @deprecated Use {#wishlist_items_count}; removed in 6.1.
    def wished_items_count
      Spree::Deprecation.warn('Spree::Wishlist#wished_items_count is deprecated and will be removed in Spree 6.1. Use #wishlist_items_count instead.')
      wishlist_items_count
    end

    # returns the variant ids in the wishlist
    #
    # @return [Array<Integer>]
    def variant_ids
      @variant_ids ||= wishlist_items.pluck(:variant_id)
    end

    private

    def ensure_default_exists_and_is_unique
      if is_default?
        Wishlist.where(is_default: true, customer_id: customer_id, store_id: store_id).where.not(id: id).update_all(is_default: false)
      end
    end
  end
end
