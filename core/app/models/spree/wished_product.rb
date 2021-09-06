module Spree
  class WishedProduct < Spree::Base
    extend DisplayMoney
    money_methods :total, :price

    belongs_to :variant
    belongs_to :wishlist

    has_one :product, through: :variant

    validates :variant, :wishlist, presence: true

    def price(currency)
      variant.price_in(currency[:currency]).amount.to_i
    end

    def total(currency)
      quantity * variant.price_in(currency[:currency]).amount.to_i
    end
  end
end
