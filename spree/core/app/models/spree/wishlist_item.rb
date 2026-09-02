module Spree
  class WishlistItem < Spree.base_class
    has_prefix_id :wli  # Spree-specific: wishlist item

    include Spree::WishlistItem::CustomEvents

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
  end
end
