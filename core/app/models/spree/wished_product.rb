module Spree
  class WishedProduct < Spree::Base
    belongs_to :variant
    belongs_to :wishlist

    has_one :product, through: :variant

    def total
      quantity * (variant.price || 0)
    end

    def display_total
      Spree::Money.new(total)
    end
  end
end
