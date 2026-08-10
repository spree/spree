module SpreeStripe
  module StoreDecorator
    # @return [SpreeStripe::Gateway, nil]
    def stripe_gateway
      @stripe_gateway ||= payment_methods.stripe.active.last
    end
  end
end

Spree::Store.prepend(SpreeStripe::StoreDecorator)
