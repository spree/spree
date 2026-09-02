module Spree
  class WishlistItem < Spree.base_class
    has_prefix_id :wli  # Spree-specific: wishlist item

    extend DisplayMoney
    money_methods :total, :price

    publishes_lifecycle_events

    belongs_to :variant, class_name: 'Spree::Variant'
    belongs_to :wishlist, class_name: 'Spree::Wishlist'

    has_one :product, class_name: 'Spree::Product', through: :variant

    validates :variant, uniqueness: { scope: [:wishlist] }
    validates :quantity, numericality: { only_integer: true, greater_than: 0 }

    def price(currency)
      variant.amount_in(currency[:currency])
    end

    def total(currency)
      variant_price = variant.amount_in(currency[:currency])

      if variant_price.nil?
        variant_price
      else
        quantity * variant_price
      end
    end

    private

    # The legacy wished_item.* events are dual-emitted for one release
    # (webhook contract bridge — removed in 6.1).
    def publish_create_event
      publish_event('wished_item.created')
      super
    end

    # Cannot call super like its siblings: touch_only_update? clears its flags
    # when read, so the guard must run exactly once for both event names.
    def publish_update_event
      return if touch_only_update?

      publish_event('wished_item.updated')
      publish_event("#{event_prefix}.updated")
    end

    def publish_delete_event
      publish_event('wished_item.deleted', @_pre_destroy_payload || event_payload)
      super
    end
  end
end
