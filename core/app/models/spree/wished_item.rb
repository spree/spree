module Spree
  class WishedItem < Spree.base_class
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end

    extend DisplayMoney
    money_methods :total, :price

    belongs_to :variant, -> { with_deleted }, class_name: 'Spree::Variant', touch: true
    belongs_to :wishlist, class_name: 'Spree::Wishlist', touch: true, inverse_of: :wished_items

    has_one :product, -> { with_deleted }, class_name: 'Spree::Product', through: :variant, source: :product

    validates :variant, :wishlist, presence: true
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
