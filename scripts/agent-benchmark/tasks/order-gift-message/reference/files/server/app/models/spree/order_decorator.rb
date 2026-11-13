module Spree
  module OrderDecorator
    def self.prepended(base)
      base.validates :gift_message, length: { maximum: 500 }, allow_blank: true
    end
  end

  Order.prepend OrderDecorator
end
