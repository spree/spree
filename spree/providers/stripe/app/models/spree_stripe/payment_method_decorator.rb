module SpreeStripe
  module PaymentMethodDecorator
    STRIPE_TYPE = 'SpreeStripe::Gateway'.freeze unless defined?(STRIPE_TYPE)

    def self.prepended(base)
      base.scope :stripe, -> { where(type: STRIPE_TYPE) }
    end

    def stripe?
      type == STRIPE_TYPE
    end
  end
end

Spree::PaymentMethod.prepend(SpreeStripe::PaymentMethodDecorator)
