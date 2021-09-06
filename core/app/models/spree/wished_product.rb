module Spree
  class WishedProduct < Spree::Base
    extend DisplayMoney
    money_methods :total, :price

    belongs_to :variant
    belongs_to :wishlist

    has_one :product, through: :variant

    validates :variant, :wishlist, presence: true

    def price(currency)
      variant_price = variant.price_in(currency[:currency]).amount

      if variant_price.nil?
        variant_price
      else
        variant_price.to_i
      end
    end

    def total(currency)
      variant_price = variant.price_in(currency[:currency]).amount

      if variant_price.nil?
        variant_price
      else
        quantity * variant_price.to_i
      end
    end
  end
end
