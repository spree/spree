module Spree
  module CartDecorator
    def self.prepended(base)
      base.validates :gift_message, length: { maximum: 500 }, allow_blank: true
    end
  end

  Cart.prepend CartDecorator
end
